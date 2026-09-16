//
//  RouteConfirmationViewModel.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/31/26.
//

import CoreLocation
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class RouteConfirmationViewModel {
    private let trip: Trip
    private let thumbnailURLsByStopID: [UUID: URL]
    private let travelMinutesByStopID: [UUID: Int]
    private let estimatedDurationMinutes: Int?
    private let directionsService: RouteDirectionsProviding

    private(set) var routeStops: [RouteStop]

    /// 계산된 경로입니다. 아직 불러오기 전이면 nil입니다.
    private(set) var directions: RouteDirections?
    /// 같은 출발지로 중복 요청하지 않기 위한 표식입니다.
    private var lastRequestSignature: String?
    /// 계산된 경로가 현재 위치에서 출발하는지 여부입니다.
    /// 구간 시간을 어느 장소에 붙일지, 출발지 표시를 그릴지 결정하는 데 씁니다.
    private(set) var startsFromCurrentLocation = false
    /// 계산에 실제로 쓰인 출발지 좌표입니다. 지도에 출발지 마커를 세울 때 씁니다.
    private(set) var routeOriginCoordinate: CLLocationCoordinate2D?
    /// 다시 시도할 때 같은 출발지를 쓰기 위해 보관합니다.
    private var lastOrigin: CLLocationCoordinate2D?
    @ObservationIgnored private var directionsTask: Task<RouteDirections, Error>?
    private var activeRequestID: UUID?

    private(set) var isLoadingDirections = false
    private(set) var directionsFailure: RequestFailure?
    private(set) var needsOrigin = false

    /// 경로를 아직 한 번도 못 그린 채 계산 중인 상태입니다.
    var isCalculatingFirstRoute: Bool {
        isLoadingDirections && directions == nil
    }

    init(
        trip: Trip,
        estimatedDurationMinutes: Int? = nil,
        thumbnailURLsByStopID: [UUID: URL] = [:],
        travelMinutesByStopID: [UUID: Int] = [:],
        directionsService: (any RouteDirectionsProviding)? = nil
    ) {
        self.trip = trip
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.thumbnailURLsByStopID = thumbnailURLsByStopID
        self.travelMinutesByStopID = travelMinutesByStopID
        self.directionsService = directionsService ?? KakaoDirectionsService()
        routeStops = trip.orderedStops
    }

    var activeTrip: Trip { trip }

    /// 지도에 세울 표시입니다. 좌표가 아직 없는 장소는 제외합니다.
    ///
    /// 출발지는 여행 '장소'가 아니라 routeStops에 없습니다.
    /// 그래서 장소 목록만으로 마커를 만들면 지도에서 출발지가 통째로 빠집니다.
    /// 경로가 출발지에서 시작할 때는 앞에 따로 한 개를 더 붙여 줍니다.
    var mapMarkers: [RouteMapMarker] {
        let stopMarkers = locatedStops.enumerated().map { index, stop in
            RouteMapMarker(
                coordinate: coordinate(of: stop),
                title: stop.name,
                kind: markerKind(for: stop, at: index)
            )
        }

        guard startsFromCurrentLocation, let routeOriginCoordinate else {
            return stopMarkers
        }

        return [
            RouteMapMarker(
                coordinate: routeOriginCoordinate,
                title: Self.originMarkerTitle,
                kind: .origin
            )
        ] + stopMarkers
    }

    /// 수동으로 입력한 위치도 그 사람에게는 현재 위치라서 문구를 나누지 않습니다.
    static let originMarkerTitle = "현재 위치"

    /// 이 장소가 경로에서 맡은 역할입니다.
    ///
    /// 지도 마커와 목록 타임라인이 같은 판정을 쓰도록 여기서만 정합니다.
    func stopKind(for stop: RouteStop) -> RouteMapMarker.Kind {
        guard let index = locatedStops.firstIndex(where: { $0.id == stop.id }) else {
            // 좌표가 없어 경로에 못 들어간 장소입니다. 목적지 여부만 보고 판단합니다.
            return stop.isDestination ? .destination : .waypoint
        }
        return markerKind(for: stop, at: index)
    }

    /// 경로에서 이 장소가 맡은 역할입니다.
    ///
    /// 현재 위치에서 출발하는 경로라면 첫 장소도 들르는 곳이므로 경유지로 봅니다.
    private func markerKind(for stop: RouteStop, at index: Int) -> RouteMapMarker.Kind {
        if stop.isDestination { return .destination }
        if index == 0, !startsFromCurrentLocation { return .origin }
        return .waypoint
    }

    /// 지도에 그릴 경로 선입니다. 계산 전이면 비어 있습니다.
    var mapPath: [CLLocationCoordinate2D] {
        directions?.path ?? []
    }

    /// 편집으로 장소가 하나도 남지 않은 상태입니다.
    ///
    /// 경로를 "불러오지 못한" 것과는 다릅니다. 다시 시도해도 달라질 것이 없고,
    /// 사용자가 장소를 다시 고르는 것 말고는 할 수 있는 일이 없습니다.
    var isRouteEmpty: Bool {
        routeStops.isEmpty
    }

    /// 좌표를 가진 장소만 추립니다. API 응답에 좌표가 빠진 경우를 걸러 냅니다.
    private var locatedStops: [RouteStop] {
        routeStops.filter { $0.latitude != 0 || $0.longitude != 0 }
    }

    // MARK: - 경로 계산

    /// 현재 위치에서 출발해 경유지를 거쳐 목적지까지의 경로를 계산합니다.
    ///
    /// 위치 권한이 없거나 아직 좌표를 못 받았으면 첫 장소를 출발지로 삼아
    /// 경로만이라도 보여 줍니다. 위치가 들어오면 다시 계산합니다.
    func loadDirections(origin: CLLocationCoordinate2D?) async {
        let stops = locatedStops
        lastOrigin = origin
        needsOrigin = false
        guard let destinationStop = stops.last else {
            cancelDirections()
            directions = nil
            startsFromCurrentLocation = false
            routeOriginCoordinate = nil
            // 장소를 다시 넣었을 때 같은 조건이라도 반드시 다시 계산하도록 표식을 지웁니다.
            lastRequestSignature = nil
            // 장소가 아예 없는 것과, 장소는 있는데 좌표가 없는 것은 다릅니다.
            // 전자는 다시 시도할 것이 없으므로 실패로 표시하지 않습니다.
            directionsFailure = isRouteEmpty ? nil : .unavailable
            return
        }

        let destination = coordinate(of: destinationStop)
        let remaining = stops.dropLast().map(coordinate(of:))

        let start: CLLocationCoordinate2D
        let waypoints: [CLLocationCoordinate2D]

        if let origin {
            start = origin
            waypoints = Array(remaining)
        } else if let first = remaining.first {
            start = first
            waypoints = Array(remaining.dropFirst())
        } else {
            // 목적지 하나뿐인데 출발지도 없으면 그릴 경로가 없습니다.
            // 잔상(이전 경로 선)이 남지 않도록 초기화해 줍니다.
            cancelDirections()
            directions = nil
            startsFromCurrentLocation = false
            routeOriginCoordinate = nil
            directionsFailure = nil
            needsOrigin = true
            return
        }

        let signature = "\(start.latitude),\(start.longitude)>"
            + waypoints.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
            + ">\(destination.latitude),\(destination.longitude)"

        guard lastRequestSignature != signature || directionsTask?.isCancelled == true else { return }
        directionsTask?.cancel()
        let requestID = UUID()
        activeRequestID = requestID
        lastRequestSignature = signature

        isLoadingDirections = true
        directionsFailure = nil
        
        // 새 경로를 계산하는 동안 이전 경로의 잔상이 지도에 남지 않도록 비워둡니다.
        // 출발지 표시도 같이 지웁니다. 남겨 두면 옛 출발지 마커가 새 경로 위에 떠 있게 됩니다.
        directions = nil
        startsFromCurrentLocation = false
        routeOriginCoordinate = nil
        
        defer {
            if activeRequestID == requestID {
                isLoadingDirections = false
                directionsTask = nil
            }
        }

        let service = directionsService
        let task = Task {
            try await service.directions(origin: start, waypoints: waypoints, destination: destination)
        }
        directionsTask = task

        do {
            let result = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            try Task.checkCancellation()
            guard activeRequestID == requestID else { return }
            directions = result
            startsFromCurrentLocation = origin != nil
            routeOriginCoordinate = origin
        } catch {
            guard activeRequestID == requestID else { return }
            // 실패한 요청은 표식을 지워서 다시 시도할 수 있게 합니다.
            lastRequestSignature = nil
            guard !Task.isCancelled, !RequestFailure.isCancellation(error) else { return }
            directionsFailure = (error as? RouteDirectionsError)?.requestFailure ?? RequestFailure(error)
        }
    }

    func cancelDirections() {
        directionsTask?.cancel()
        directionsTask = nil
        activeRequestID = nil
        if isLoadingDirections { lastRequestSignature = nil }
        isLoadingDirections = false
    }

    private func coordinate(of stop: RouteStop) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
    }

    var routeSummary: String {
        // 저장해 둔 거리·시간이 남아 있어도 보여 주면 안 됩니다.
        // 지금 화면에 아무 장소도 없는데 지난 경로의 숫자가 남으면 그걸 믿고 진행하게 됩니다.
        if isRouteEmpty { return "남은 장소가 없어요" }
        if isLoadingDirections { return "경로 정보를 계산하고 있어요" }
        if directionsFailure != nil { return "경로 정보를 불러오지 못했어요" }
        if needsOrigin { return "출발 위치를 확인하면 거리·시간을 표시할 수 있어요" }
        var values: [String] = []

        if let distanceText {
            values.append(distanceText)
        }

        if let durationText {
            values.append(durationText)
        }

        guard !values.isEmpty else {
            return "경로 정보가 없어요"
        }

        values.append("자동차 기준")
        return values.joined(separator: " · ")
    }

    /// 요약 숫자가 어림값임을 알려 주는 문구입니다.
    var routeSummaryCaption: String? {
        guard !isRouteEmpty, directions != nil else { return nil }
        return "실제 소요 시간은 출발 시각과 교통 상황에 따라 달라져요"
    }

    /// 직전 지점에서 이 장소까지 걸리는 시간(분)입니다.
    ///
    /// 경로 응답의 leg는 "출발지 → 첫 지점", "첫 지점 → 두 번째 지점" 순서라
    /// 장소 순번에 그대로 대응합니다. 다만 현재 위치에서 출발하지 못한 경우에는
    /// 첫 장소가 곧 출발지이므로 한 칸씩 밀어서 맞춥니다.
    func travelMinutes(before stop: RouteStop) -> Int? {
        guard let legs = directions?.legs else {
            return travelMinutesByStopID[stop.id]
        }

        guard let index = locatedStops.firstIndex(where: { $0.id == stop.id }) else {
            return nil
        }

        let legIndex = startsFromCurrentLocation ? index : index - 1

        guard legs.indices.contains(legIndex) else { return nil }
        return legs[legIndex].durationMinutes
    }

    func beginEditing() {
        routeStops = trip.orderedStops
    }

    func commitEditing() {
        let remainingStopIDs = Set(routeStops.map(\.id))

        stampPixelCodeIfDestinationIsLeaving(remainingStopIDs: remainingStopIDs)

        for stop in trip.stops where !remainingStopIDs.contains(stop.id) {
            stop.trip = nil
        }

        for (index, stop) in routeStops.enumerated() {
            stop.trip = trip
            stop.orderIndex = index
        }

        trip.stops = routeStops

        // 편집된 순서/삭제 결과에 맞춰 지도 API(경로)를 다시 그려줍니다.
        Task {
            await loadDirections(origin: lastOrigin)
        }
    }

    /// 최종 목적지를 지우기 직전에 이 여행이 채울 지역을 Trip에 새겨 둡니다.
    ///
    /// 지역은 목적지 좌표로 판정하는데, 목적지를 지우면 그 좌표가 사라져
    /// 이후로는 어느 지역을 여행했는지 알 길이 없어집니다.
    /// 목적지를 바꾸는 것과 "이 여행이 어느 지역인가"는 다른 이야기라,
    /// 지우더라도 처음 정해진 지역으로 픽셀을 채울 수 있어야 합니다.
    ///
    /// 경계 데이터가 3.5MB라 판정 비용이 작지 않습니다.
    /// 그래서 실제로 목적지가 빠지는 순간에만, 그것도 한 번만 계산합니다.
    private func stampPixelCodeIfDestinationIsLeaving(remainingStopIDs: Set<UUID>) {
        guard trip.targetPixelCode == nil,
              let destinationStop = trip.destinationStop,
              !remainingStopIDs.contains(destinationStop.id) else { return }

        trip.targetPixelCode = trip.pixelTile?.code
    }

    /// 목록을 비워 버린 삭제 직전의 상태입니다. 되돌리기에만 씁니다.
    ///
    /// routeStops에서 빼는 것은 배열 조작일 뿐이고 SwiftData에서 지우는 것은
    /// commitEditing 시점이라, 배열만 되돌려 놓으면 그대로 복구됩니다.
    private var routeStopsBeforeEmptying: [RouteStop]?

    func removeStops(at offsets: IndexSet) {
        let before = routeStops

        for index in offsets.sorted(by: >) where routeStops.indices.contains(index) {
            routeStops.remove(at: index)
        }

        // 마지막 하나까지 지운 경우에만 되돌릴 거리를 남깁니다.
        // 중간 삭제까지 기억해 두면 언제 되돌려야 할지가 모호해집니다.
        routeStopsBeforeEmptying = routeStops.isEmpty ? before : nil
    }

    /// 목록을 비운 그 삭제를 되돌립니다.
    ///
    /// 장소를 모두 지웠을 때 안내에서 "취소"를 고른 경우입니다.
    /// 지우기 전 전체가 아니라 마지막 삭제 한 번만 되돌립니다.
    func undoEmptyingRemoval() {
        guard let routeStopsBeforeEmptying else { return }
        routeStops = routeStopsBeforeEmptying
        self.routeStopsBeforeEmptying = nil
    }

    func moveStops(from offsets: IndexSet, to destination: Int) {
        routeStops.move(fromOffsets: offsets, toOffset: destination)
    }

    func thumbnailURL(for stop: RouteStop) -> URL? {
        thumbnailURLsByStopID[stop.id] ?? stop.photoURL.flatMap(URL.init(string:))
    }

    private var distanceText: String? {
        // 계산된 경로가 있으면 그 값을, 없으면 저장된 값을 씁니다.
        let meters = directions.map { Double($0.distanceMeters) } ?? trip.totalDistanceMeters
        guard let meters else { return nil }

        let kilometers = meters / 1_000
        let formattedDistance = kilometers.formatted(
            .number.precision(.fractionLength(kilometers < 10 ? 0...1 : 0...0))
        )
        return "총 \(formattedDistance)km"
    }

    private var durationText: String? {
        let totalMinutes = directions.map { Int(($0.duration / 60).rounded()) }
            ?? estimatedDurationMinutes
        guard let totalMinutes else { return nil }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch (hours, minutes) {
        case (0, let minutes):
            return "약 \(minutes)분"
        case (let hours, 0):
            return "약 \(hours)시간"
        default:
            return "약 \(hours)시간 \(minutes)분"
        }
    }
}
