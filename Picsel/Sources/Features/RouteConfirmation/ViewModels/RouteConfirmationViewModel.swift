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
    private let coordinateCorrector: RouteCoordinateCorrecting

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
    /// 자동차로 갈 수 없어 경로에 넣을 수 없는 장소입니다.
    ///
    /// 여행 목록에서 지우지는 않습니다. 사용자가 고른 장소를 앱이 말없이 없애면 안 되고,
    /// 걸어서 갈 수 있는 곳일 수도 있습니다. 경로 계산에서만 빼고 화면에 그 사실을 밝힙니다.
    private(set) var unreachableStopIDs: Set<UUID> = []
    /// 경로 계산에 실제로 들어간 장소의 순서입니다.
    ///
    /// 갈 수 없는 장소를 빼고 다시 계산하면 응답의 구간 수가 목록보다 적어집니다.
    /// 목록 순번으로 구간을 세면 한 칸씩 밀려 엉뚱한 장소에 시간이 붙습니다.
    private var routedStopIDs: [UUID] = []
    /// 도로 쪽으로 옮겨 놓은 좌표입니다. 장소 본래의 좌표는 건드리지 않습니다.
    ///
    /// 관광 API가 주는 좌표는 "사진을 찍은 자리"라 산 중턱이거나 물 위일 수 있습니다.
    /// 길찾기에는 그 좌표가 쓸모없지만, 저장된 좌표는 여행 기록과 픽셀 판정의 근거라
    /// 길찾기 사정으로 고쳐 쓰면 안 됩니다. 그래서 계산할 때만 이 값으로 갈아 끼웁니다.
    private var correctedCoordinates: [UUID: CLLocationCoordinate2D] = [:]
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
        directionsService: (any RouteDirectionsProviding)? = nil,
        coordinateCorrector: (any RouteCoordinateCorrecting)? = nil
    ) {
        self.trip = trip
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.thumbnailURLsByStopID = thumbnailURLsByStopID
        self.travelMinutesByStopID = travelMinutesByStopID
        self.directionsService = directionsService ?? KakaoDirectionsService()
        self.coordinateCorrector = coordinateCorrector ?? NaverCoordinateCorrector()
        routeStops = trip.orderedStops
    }

    var activeTrip: Trip { trip }

    /// 지도에 세울 표시입니다. 좌표가 아직 없는 장소는 제외합니다.
    ///
    /// 출발지는 여행 '장소'가 아니라 routeStops에 없습니다.
    /// 그래서 장소 목록만으로 마커를 만들면 지도에서 출발지가 통째로 빠집니다.
    /// 경로가 출발지에서 시작할 때는 앞에 따로 한 개를 더 붙여 줍니다.
    var mapMarkers: [RouteMapMarker] {
        let stopMarkers = routedStops.enumerated().map { index, stop in
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
        guard let index = routedStops.firstIndex(where: { $0.id == stop.id }) else {
            // 좌표가 없거나 갈 수 없어 경로에 못 들어간 장소입니다.
            // 목적지 여부만 보고 판단합니다.
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

    /// 경로에 실제로 들어간 장소들입니다. 아직 계산 전이면 좌표를 가진 장소 전부로 봅니다.
    ///
    /// 지도 마커와 구간 시간은 목록이 아니라 이 순서를 기준으로 삼아야 합니다.
    private var routedStops: [RouteStop] {
        guard !routedStopIDs.isEmpty else { return locatedStops }
        return routedStopIDs.compactMap { id in locatedStops.first { $0.id == id } }
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
            resetRouteState()
            // 장소를 다시 넣었을 때 같은 조건이라도 반드시 다시 계산하도록 표식을 지웁니다.
            lastRequestSignature = nil
            // 장소가 아예 없는 것과, 장소는 있는데 좌표가 없는 것은 다릅니다.
            // 전자는 다시 시도할 것이 없으므로 실패로 표시하지 않습니다.
            directionsFailure = isRouteEmpty ? nil : .unavailable
            return
        }

        let remainingStops = Array(stops.dropLast())

        let start: CLLocationCoordinate2D
        // 좌표만 들고 다니면 나중에 "몇 번째 경유지가 문제인가"를 장소와 이어 붙일 수 없습니다.
        let waypointStops: [RouteStop]
        // 현재 위치를 못 받아 첫 장소를 출발지로 쓴 경우입니다.
        // 이 장소도 경로 위에 있으므로 지도 마커와 구간 계산에서 빠지면 안 됩니다.
        let startStop: RouteStop?

        if let origin {
            start = origin
            startStop = nil
            waypointStops = remainingStops
        } else if let first = remainingStops.first {
            // 보정 좌표는 계산을 시작하면서 지우므로, 여기서는 장소 본래의 좌표를 씁니다.
            start = rawCoordinate(of: first)
            startStop = first
            waypointStops = Array(remainingStops.dropFirst())
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

        let plannedStops = Self.routedList(
            startStop: startStop,
            waypointStops: waypointStops,
            destinationStop: destinationStop
        )
        let signature = Self.requestSignature(origin: origin, stops: plannedStops)

        guard lastRequestSignature != signature || directionsTask?.isCancelled == true else { return }
        directionsTask?.cancel()
        let requestID = UUID()
        activeRequestID = requestID
        lastRequestSignature = signature

        isLoadingDirections = true
        directionsFailure = nil
        
        // 새 경로를 계산하는 동안 이전 경로의 잔상이 지도에 남지 않도록 비워둡니다.
        // 출발지 표시도 같이 지웁니다. 남겨 두면 옛 출발지 마커가 새 경로 위에 떠 있게 됩니다.
        resetRouteState()

        // 보정 좌표까지 지운 뒤에 꺼내야 첫 계산이 장소 본래의 좌표로 나갑니다.
        let waypoints = waypointStops.map(coordinate(of:))
        let destination = coordinate(of: destinationStop)

        defer {
            if activeRequestID == requestID {
                isLoadingDirections = false
                directionsTask = nil
            }
        }

        do {
            let result = try await requestDirections(
                origin: start,
                waypoints: waypoints,
                destination: destination
            )
            try Task.checkCancellation()
            guard activeRequestID == requestID else { return }
            apply(result, origin: origin, routedStops: plannedStops)
        } catch {
            guard activeRequestID == requestID else { return }
            guard !Task.isCancelled, !RequestFailure.isCancellation(error) else { return }

            let failure = (error as? RouteDirectionsError)?.requestFailure ?? RequestFailure(error)

            // 갈 수 없는 장소 때문이 아니라면 빼 볼 것이 없습니다.
            guard failure == .unreachableWaypoint else {
                lastRequestSignature = nil
                directionsFailure = failure
                return
            }

            await retryWithoutUnreachableStops(
                origin: origin,
                start: start,
                startStop: startStop,
                waypointStops: waypointStops,
                destinationStop: destinationStop,
                requestID: requestID,
                originalFailure: failure
            )
        }
    }

    /// 업체에 경로를 한 번 물어봅니다. 화면을 떠나면 취소되도록 함께 묶어 둡니다.
    private func requestDirections(
        origin: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) async throws -> RouteDirections {
        let service = directionsService
        let task = Task {
            try await service.directions(
                origin: origin,
                waypoints: waypoints,
                destination: destination
            )
        }
        directionsTask = task

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: { task.cancel() }
    }

    /// 경로가 지나는 장소를 순서대로 모읍니다.
    ///
    /// 현재 위치에서 출발하지 못한 경우 첫 장소가 곧 출발지입니다.
    /// 그 장소도 경로 위에 있으므로 목록 맨 앞에 넣어야, 지도 마커의 역할 판정과
    /// 구간 시간 계산이 지금까지와 같은 기준으로 동작합니다.
    private static func routedList(
        startStop: RouteStop?,
        waypointStops: [RouteStop],
        destinationStop: RouteStop
    ) -> [RouteStop] {
        [startStop].compactMap { $0 } + waypointStops + [destinationStop]
    }

    /// 같은 요청인지 가리는 표식입니다.
    ///
    /// 보정된 좌표가 아니라 장소 본래의 좌표로 만듭니다.
    /// 보정은 계산 도중에 생겨나는 값이라, 그것까지 넣으면 조건이 그대로인데도
    /// 표식이 매번 달라져서 화면을 열 때마다 경로를 새로 물어보게 됩니다.
    private static func requestSignature(
        origin: CLLocationCoordinate2D?,
        stops: [RouteStop]
    ) -> String {
        let originText = origin.map { "\($0.latitude),\($0.longitude)" } ?? "-"
        let stopsText = stops.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
        return "\(originText)>\(stopsText)"
    }

    /// 지난 계산의 흔적을 모두 지웁니다.
    ///
    /// 하나라도 남기면 옛 출발지 마커나 지난 경로 선이 새 경로 위에 겹쳐 뜹니다.
    private func resetRouteState() {
        directions = nil
        startsFromCurrentLocation = false
        routeOriginCoordinate = nil
        unreachableStopIDs = []
        routedStopIDs = []
        correctedCoordinates = [:]
    }

    /// 계산 결과를 화면이 쓰는 상태로 옮깁니다.
    private func apply(
        _ result: RouteDirections,
        origin: CLLocationCoordinate2D?,
        routedStops: [RouteStop]
    ) {
        directions = result
        startsFromCurrentLocation = origin != nil
        routeOriginCoordinate = origin
        routedStopIDs = routedStops.map(\.id)
        directionsFailure = nil
    }

    /// 갈 수 없는 장소를 골라내 빼고 한 번 더 계산합니다.
    ///
    /// 장소 하나 때문에 경로 전체를 못 보여 주는 것보다, 갈 수 있는 곳까지의 경로를 주고
    /// 무엇이 빠졌는지 밝히는 편이 낫습니다. 뺀 사실을 감추면 그때는 거짓말이 됩니다.
    private func retryWithoutUnreachableStops(
        origin: CLLocationCoordinate2D?,
        start: CLLocationCoordinate2D,
        startStop: RouteStop?,
        waypointStops: [RouteStop],
        destinationStop: RouteStop,
        requestID: UUID,
        originalFailure: RequestFailure
    ) async {
        await markUnreachableStops(
            origin: start,
            waypointStops: waypointStops,
            requestID: requestID
        )
        guard activeRequestID == requestID else { return }

        // 범인을 못 찾았으면 뺄 것이 없습니다. 원래 실패를 그대로 남깁니다.
        guard !unreachableStopIDs.isEmpty else {
            lastRequestSignature = nil
            directionsFailure = originalFailure
            return
        }

        let blockedStops = waypointStops.filter { unreachableStopIDs.contains($0.id) }

        // 빼기 전에 먼저 옮겨 봅니다. 자리를 옮겨 길이 잡히면 그 장소는 경로에 남습니다.
        await correctUnreachableStops(blockedStops, requestID: requestID)
        guard activeRequestID == requestID else { return }
        let didCorrect = !correctedCoordinates.isEmpty

        // 경유지가 전부 빠져도 출발지에서 목적지까지는 그릴 수 있습니다.
        var failure = await requestAndApply(
            origin: origin,
            start: start,
            startStop: startStop,
            waypointStops: waypointStops.filter { !unreachableStopIDs.contains($0.id) },
            destinationStop: destinationStop,
            requestID: requestID
        )

        // 옮긴 좌표로도 길이 안 잡히는 경우입니다.
        // 보정을 포기하고 원래대로 빼서, 갈 수 있는 곳까지의 경로라도 남깁니다.
        if failure != nil, didCorrect, activeRequestID == requestID {
            correctedCoordinates = [:]
            unreachableStopIDs = Set(blockedStops.map(\.id))

            failure = await requestAndApply(
                origin: origin,
                start: start,
                startStop: startStop,
                waypointStops: waypointStops.filter { !unreachableStopIDs.contains($0.id) },
                destinationStop: destinationStop,
                requestID: requestID
            )
        }

        guard let failure, activeRequestID == requestID else { return }
        lastRequestSignature = nil
        directionsFailure = failure
    }

    /// 주어진 경유지로 한 번 계산해 화면에 반영합니다.
    ///
    /// 실패하면 그 이유를 돌려줍니다. 성공했거나, 화면을 떠나 결과가 쓸모없어졌으면
    /// 더 할 일이 없다는 뜻으로 nil을 돌려줍니다.
    private func requestAndApply(
        origin: CLLocationCoordinate2D?,
        start: CLLocationCoordinate2D,
        startStop: RouteStop?,
        waypointStops: [RouteStop],
        destinationStop: RouteStop,
        requestID: UUID
    ) async -> RequestFailure? {
        do {
            let result = try await requestDirections(
                origin: start,
                waypoints: waypointStops.map(coordinate(of:)),
                destination: coordinate(of: destinationStop)
            )
            try Task.checkCancellation()
            guard activeRequestID == requestID else { return nil }
            apply(
                result,
                origin: origin,
                routedStops: Self.routedList(
                    startStop: startStop,
                    waypointStops: waypointStops,
                    destinationStop: destinationStop
                )
            )
            return nil
        } catch {
            guard activeRequestID == requestID else { return nil }
            guard !Task.isCancelled, !RequestFailure.isCancellation(error) else { return nil }
            return (error as? RouteDirectionsError)?.requestFailure ?? RequestFailure(error)
        }
    }

    /// 갈 수 없다고 판정된 장소를 도로 가까운 지점으로 옮겨 봅니다.
    ///
    /// 주소는 사람이 찾아가는 곳을 가리키므로, 주소를 다시 좌표로 바꾸면 도로 쪽 지점이 나옵니다.
    /// 옮기는 데 성공한 장소는 갈 수 없는 목록에서 빼내 경로에 다시 넣습니다.
    /// 도로명주소가 없어 옮기지 못한 장소만 최종적으로 경로에서 빠집니다.
    private func correctUnreachableStops(_ stops: [RouteStop], requestID: UUID) async {
        // RouteStop은 다른 실행 흐름으로 넘길 수 없으므로 필요한 값만 미리 꺼내 둡니다.
        let targets = stops.map {
            (id: $0.id, name: $0.name, address: $0.address, coordinate: coordinate(of: $0))
        }
        guard !targets.isEmpty else { return }

        let corrector = coordinateCorrector
        let corrections = await withTaskGroup(
            of: (id: UUID, correction: RouteCoordinateCorrection?).self
        ) { group in
            for target in targets {
                group.addTask {
                    (
                        target.id,
                        await corrector.correctedCoordinate(
                            forName: target.name,
                            address: target.address,
                            near: target.coordinate
                        )
                    )
                }
            }

            var found: [UUID: RouteCoordinateCorrection] = [:]
            for await result in group {
                if let correction = result.correction { found[result.id] = correction }
            }
            return found
        }

        // 기다리는 사이 더 새로운 요청이 시작됐다면 이 결과는 낡은 것입니다.
        guard activeRequestID == requestID else { return }

        #if DEBUG
        // 갈아 끼우기 전에 남겨야 옮기기 전 좌표가 찍힙니다.
        for stop in stops {
            let correction = corrections[stop.id]
            RouteCoordinateDiagnostics.record(
                name: stop.name,
                address: stop.address,
                from: coordinate(of: stop),
                to: correction?.coordinate,
                step: correction?.stepDescription
            )
        }
        #endif

        let correctedCoordinatesMap = corrections.mapValues(\.coordinate)
        correctedCoordinates.merge(correctedCoordinatesMap) { _, new in new }
        unreachableStopIDs.subtract(corrections.keys)
    }


    /// 자동차로 갈 수 없는 장소를 골라내 표시해 둡니다.
    ///
    /// 업체에 지점마다 따로 물어보므로 경유지 수만큼 요청이 더 나갑니다.
    /// 실패했을 때만 부르기 때문에, 잘 되는 경로에는 이 비용이 붙지 않습니다.
    private func markUnreachableStops(
        origin: CLLocationCoordinate2D,
        waypointStops: [RouteStop],
        requestID: UUID
    ) async {
        let indices = await directionsService.unreachableWaypointIndices(
            origin: origin,
            waypoints: waypointStops.map(coordinate(of:))
        )

        // 기다리는 사이 더 새로운 요청이 시작됐다면 이 결과는 낡은 것입니다.
        guard activeRequestID == requestID else { return }

        unreachableStopIDs = Set(
            indices
                .filter { waypointStops.indices.contains($0) }
                .map { waypointStops[$0].id }
        )
    }

    /// 이 장소가 자동차로 갈 수 없어 경로에서 빠졌는지 여부입니다.
    func isUnreachable(_ stop: RouteStop) -> Bool {
        unreachableStopIDs.contains(stop.id)
    }

    /// 경로에서 뺀 장소가 있다는 사실을 알리는 문구입니다. 뺀 것이 없으면 nil입니다.
    ///
    /// 뺀 사실을 감추면 사용자는 "왜 저기는 안 들르지?"만 남습니다.
    /// 어디가 빠졌는지는 각 줄에서 밝히고, 여기서는 일이 있었다는 것과 할 수 있는 일을 알립니다.
    var unreachableNotice: String? {
        guard !unreachableStopIDs.isEmpty else { return nil }
        return "자동차로 갈 수 없는 \(unreachableStopIDs.count)곳을 경로에서 뺐어요. 편집에서 지울 수 있어요."
    }

    func cancelDirections() {
        directionsTask?.cancel()
        directionsTask = nil
        activeRequestID = nil
        if isLoadingDirections { lastRequestSignature = nil }
        isLoadingDirections = false
    }

    /// 경로 계산과 지도에 쓸 좌표입니다. 옮겨 놓은 좌표가 있으면 그것을 씁니다.
    ///
    /// 경로 선과 마커가 같은 지점을 가리키도록 두 곳 모두 이 값을 통해 좌표를 꺼냅니다.
    private func coordinate(of stop: RouteStop) -> CLLocationCoordinate2D {
        correctedCoordinates[stop.id] ?? rawCoordinate(of: stop)
    }

    /// 장소가 원래 들고 있는 좌표입니다.
    private func rawCoordinate(of stop: RouteStop) -> CLLocationCoordinate2D {
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
    /// 응답에 구간이 없거나 예외인 경우에도 직전 장소와의 거리 기반 어림값을 계산해 정상 표시합니다.
    func travelMinutes(before stop: RouteStop) -> Int? {
        if let legs = directions?.legs,
           let index = routedStops.firstIndex(where: { $0.id == stop.id }) {
            let legIndex = startsFromCurrentLocation ? index : index - 1
            if legs.indices.contains(legIndex), let minutes = legs[legIndex].durationMinutes {
                return minutes
            }
        }

        if let saved = travelMinutesByStopID[stop.id] {
            return saved
        }

        // 경로 응답이나 저장된 값이 없는 경우 직전 지점과의 거리 기반으로 어림 시간을 계산합니다.
        guard let stopIndex = routeStops.firstIndex(where: { $0.id == stop.id }) else {
            return nil
        }

        let previousCoordinate: CLLocationCoordinate2D?
        if stopIndex == 0 {
            previousCoordinate = startsFromCurrentLocation ? routeOriginCoordinate : nil
        } else {
            let prevStop = routeStops[stopIndex - 1]
            previousCoordinate = coordinate(of: prevStop)
        }

        guard let previousCoordinate else { return nil }

        let prevLocation = CLLocation(latitude: previousCoordinate.latitude, longitude: previousCoordinate.longitude)
        let currentLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
        let distanceMeters = prevLocation.distance(from: currentLocation)

        // 자동차 기준(시속 약 45km = 분당 750m) 어림 시간 계산
        let estimatedMinutes = max(1, Int((distanceMeters / 750.0).rounded()))
        return estimatedMinutes
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
