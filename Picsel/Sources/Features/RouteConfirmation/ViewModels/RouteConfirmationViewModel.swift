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

    private(set) var isLoadingDirections = false
    /// 화면에는 노출하지 않고 콘솔 확인용으로만 둡니다.
    /// 실패해도 요약 문구가 "경로 정보를 계산하고 있어요"로 남아 조용히 처리됩니다.
    private(set) var directionsErrorMessage: String?

    /// 경로를 아직 한 번도 못 그린 채 계산 중인 상태입니다.
    var isCalculatingFirstRoute: Bool {
        isLoadingDirections && directions == nil
    }

    init(
        trip: Trip,
        estimatedDurationMinutes: Int? = nil,
        thumbnailURLsByStopID: [UUID: URL] = [:],
        travelMinutesByStopID: [UUID: Int] = [:],
        directionsService: RouteDirectionsProviding = KakaoDirectionsService()
    ) {
        self.trip = trip
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.thumbnailURLsByStopID = thumbnailURLsByStopID
        self.travelMinutesByStopID = travelMinutesByStopID
        self.directionsService = directionsService
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
        guard let destinationStop = stops.last else { return }

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
            directions = nil
            lastRequestSignature = nil
            return
        }

        let signature = "\(start.latitude),\(start.longitude)>"
            + waypoints.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
            + ">\(destination.latitude),\(destination.longitude)"

        guard lastRequestSignature != signature else { return }
        lastRequestSignature = signature
        lastOrigin = origin

        isLoadingDirections = true
        directionsErrorMessage = nil
        
        // 새 경로를 계산하는 동안 이전 경로의 잔상이 지도에 남지 않도록 비워둡니다.
        // 출발지 표시도 같이 지웁니다. 남겨 두면 옛 출발지 마커가 새 경로 위에 떠 있게 됩니다.
        directions = nil
        startsFromCurrentLocation = false
        routeOriginCoordinate = nil
        
        defer { isLoadingDirections = false }

        do {
            directions = try await directionsService.directions(
                origin: start,
                waypoints: waypoints,
                destination: destination
            )
            startsFromCurrentLocation = origin != nil
            routeOriginCoordinate = origin
        } catch {
            // 실패한 요청은 표식을 지워서 다시 시도할 수 있게 합니다.
            lastRequestSignature = nil
            directionsErrorMessage = (error as? RouteDirectionsError)?.errorDescription
                ?? "경로를 계산하지 못했어요."
            print("경로 계산 실패: \(error)")
        }
    }

    /// 실패했을 때 같은 조건으로 한 번 더 계산합니다.
    func retryDirections() async {
        await loadDirections(origin: lastOrigin)
    }

    private func coordinate(of stop: RouteStop) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
    }

    var routeSummary: String {
        var values: [String] = []

        if let distanceText {
            values.append(distanceText)
        }

        if let durationText {
            values.append(durationText)
        }

        guard !values.isEmpty else {
            return "경로 정보를 계산하고 있어요"
        }

        values.append("자동차 기준")
        return values.joined(separator: " · ")
    }

    /// 요약 숫자가 어림값임을 알려 주는 문구입니다.
    var routeSummaryCaption: String? {
        directions == nil
            ? nil
            : "실제 소요 시간은 출발 시각과 교통 상황에 따라 달라져요"
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

    func removeStops(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where routeStops.indices.contains(index) {
            routeStops.remove(at: index)
        }
    }

    func moveStops(from offsets: IndexSet, to destination: Int) {
        routeStops.move(fromOffsets: offsets, toOffset: destination)
    }

    func thumbnailURL(for stop: RouteStop) -> URL? {
        thumbnailURLsByStopID[stop.id]
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
