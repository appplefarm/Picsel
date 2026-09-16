//
//  KakaoDirectionsService.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import CoreLocation
import Foundation

/// 카카오 모빌리티 다중 경유지 길찾기로 자동차 경로를 계산합니다.
///
/// 네이버 Directions 15를 대체합니다. 경유지 상한이 15개에서 30개로 늘고,
/// 무료 쿼터가 월 3,000건에서 일 5,000건으로 바뀌어 출시 후 비용을 감당할 수 있습니다.
/// 응답을 그대로 노출하지 않고 RouteDirections로 변환해 화면에서 업체를 몰라도 되게 합니다.
struct KakaoDirectionsService: RouteDirectionsProviding {

    /// 카카오 모빌리티가 한 번에 받을 수 있는 경유지 수입니다.
    static let maximumWaypointCount = 30

    /// 카카오 모빌리티가 허용하는 총 경로 길이 상한(m)입니다.
    /// 이 값을 넘으면 서버가 경로를 계산하지 않습니다.
    static let maximumRouteDistanceMeters: Double = 1_500_000

    private let session: URLSession
    private let baseURL = URL(string: "https://apis-navi.kakaomobility.com/v1/waypoints/directions")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func directions(
        origin: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) async throws -> RouteDirections {
        let trimmedWaypoints = Array(waypoints.prefix(Self.maximumWaypointCount))

        // 직선 거리 합만으로 이미 상한을 넘으면 서버도 계산하지 못합니다.
        // 실제 도로 거리는 직선 거리보다 항상 길기 때문에, 미리 걸러도 멀쩡한 경로를 막을 일이 없습니다.
        // 어차피 실패할 요청으로 하루 쿼터를 깎지 않으려고 호출 전에 확인합니다.
        guard Self.straightLineDistance(
            origin: origin,
            waypoints: trimmedWaypoints,
            destination: destination
        ) < Self.maximumRouteDistanceMeters else {
            throw RouteDirectionsError.routeTooLong
        }

        let request = try makeRequest(
            origin: origin,
            waypoints: trimmedWaypoints,
            destination: destination
        )

        #if DEBUG
        KakaoDirectionsDiagnostics.record(
            origin: origin,
            waypoints: trimmedWaypoints,
            destination: destination
        )
        #endif

        let startedAt = Date()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled || RequestFailure.isCancellation(error) { throw CancellationError() }
            #if DEBUG
            KakaoDirectionsDiagnostics.record(
                networkError: error,
                waypointCount: trimmedWaypoints.count,
                elapsed: Date().timeIntervalSince(startedAt)
            )
            #endif
            throw RouteDirectionsError.networkFailure(underlying: error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? -1

        // 실패 문구는 원인을 뭉개서 보여 주므로, 업체가 실제로 뭐라고 했는지는 여기서만 남습니다.
        #if DEBUG
        KakaoDirectionsDiagnostics.record(
            status: status,
            waypointCount: trimmedWaypoints.count,
            elapsed: Date().timeIntervalSince(startedAt),
            data: data
        )
        #endif

        // 키가 틀리거나 권한이 없으면 routes 없이 게이트웨이 에러만 내려옵니다.
        if !(200..<300).contains(status) {
            throw Self.gatewayError(status: status, data: data)
        }

        let decoded = try JSONDecoder().decode(KakaoDirectionsResponseDTO.self, from: data)

        guard let route = decoded.routes.first else {
            throw RouteDirectionsError.routeNotFound
        }

        // 요청 자체는 200이어도 경로 계산에 실패하면 result_code로 알려 줍니다.
        guard route.resultCode == 0 else {
            throw Self.routeError(code: route.resultCode, message: route.resultMessage)
        }

        guard let directions = route.toDomain(
            waypoints: trimmedWaypoints,
            destination: destination
        ) else {
            throw RouteDirectionsError.routeNotFound
        }

        return directions
    }

    // MARK: - 갈 수 없는 경유지 골라내기

    /// 경유지 하나하나에 "여기까지 자동차로 갈 수 있나"를 따로 물어봅니다.
    ///
    /// 카카오는 경유지 중에 못 가는 곳이 있다는 사실만 알려 주고 어느 것인지는 말하지 않습니다.
    /// 하나씩 빼 보며 찾으면 경유지 수만큼 왕복이 쌓이므로, 전부 동시에 물어 한 번에 끝냅니다.
    ///
    /// 경유지가 아니라 목적지 자리에 넣어 물어봅니다. 그래야 그 지점 하나만의 문제인지가
    /// 다른 지점에 가려지지 않습니다.
    func unreachableWaypointIndices(
        origin: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D]
    ) async -> Set<Int> {
        let trimmed = Array(waypoints.prefix(Self.maximumWaypointCount))
        guard !trimmed.isEmpty else { return [] }

        let indices = await withTaskGroup(of: (offset: Int, isUnreachable: Bool).self) { group in
            for (offset, waypoint) in trimmed.enumerated() {
                group.addTask { (offset, await self.isUnreachable(from: origin, to: waypoint)) }
            }

            var found: Set<Int> = []
            for await result in group where result.isUnreachable {
                found.insert(result.offset)
            }
            return found
        }

        #if DEBUG
        KakaoDirectionsDiagnostics.recordUnreachable(indices: indices, of: trimmed)
        #endif

        return indices
    }

    private func isUnreachable(
        from origin: CLLocationCoordinate2D,
        to waypoint: CLLocationCoordinate2D
    ) async -> Bool {
        do {
            _ = try await directions(origin: origin, waypoints: [], destination: waypoint)
            return false
        } catch let error as RouteDirectionsError {
            switch error {
            // 업체가 "이 지점으로는 경로를 만들 수 없다"고 판단한 경우입니다.
            // 코드가 무엇이든 결론은 같으므로 한데 묶습니다.
            case .unreachableWaypoint, .providerError, .routeNotFound, .routeTooLong:
                return true
            // 네트워크나 키 문제는 이 지점의 잘못이 아닙니다.
            // 여기서 true를 돌려주면 멀쩡한 장소를 경로에서 빼 버리게 됩니다.
            case .networkFailure, .missingAPIKey, .invalidRequest:
                return false
            }
        } catch {
            return false
        }
    }

    // MARK: - 요청 만들기

    private func makeRequest(
        origin: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) throws -> URLRequest {
        guard
            let restAPIKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String,
            !restAPIKey.isEmpty,
            !restAPIKey.contains("$(")
        else {
            throw RouteDirectionsError.missingAPIKey
        }

        let body = KakaoDirectionsRequestDTO(
            origin: .init(origin),
            destination: .init(destination),
            waypoints: waypoints.isEmpty ? nil : waypoints.map(KakaoDirectionsRequestDTO.Point.init),
            // RECOMMEND: 카카오내비가 기본으로 안내하는 추천 경로입니다.
            priority: "RECOMMEND",
            alternatives: false,
            roadDetails: false
        )

        guard let httpBody = try? JSONEncoder().encode(body) else {
            throw RouteDirectionsError.invalidRequest
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("KakaoAK \(restAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        return request
    }

    /// 카카오가 "경유지 지점 주변의 도로를 탐색할 수 없음"으로 거절할 때의 코드입니다.
    private static let unreachableWaypointCode = 101

    /// 경로 계산 실패 코드를 화면이 다룰 수 있는 실패로 옮깁니다.
    ///
    /// 101만 따로 빼는 이유는 대응이 완전히 다르기 때문입니다.
    /// 나머지는 잠시 후 다시 해보면 될 수 있지만, 101은 좌표가 그대로인 한 언제 다시 보내도
    /// 같은 대답이 옵니다. 같은 문구로 묶어 두면 "다시 시도"가 영원히 듣지 않습니다.
    private static func routeError(code: Int, message: String?) -> RouteDirectionsError {
        guard code != unreachableWaypointCode else { return .unreachableWaypoint }

        return .providerError(
            code: String(code),
            message: message ?? "경로를 계산하지 못했어요."
        )
    }

    private static func gatewayError(status: Int, data: Data) -> RouteDirectionsError {
        let message = (try? JSONDecoder().decode(KakaoGatewayErrorDTO.self, from: data))?.displayMessage

        if status == 401 || status == 403 {
            return .providerError(
                code: String(status),
                message: message ?? "카카오 모빌리티 API 키를 확인해 주세요."
            )
        }

        return .providerError(
            code: String(status),
            message: message ?? "경로를 계산하지 못했어요."
        )
    }

    /// 출발지 → 경유지 → 목적지를 직선으로 이었을 때의 총 길이(m)입니다.
    private static func straightLineDistance(
        origin: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) -> Double {
        let points = [origin] + waypoints + [destination]
        return zip(points, points.dropFirst()).reduce(into: 0.0) { total, pair in
            total += CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                .distance(from: CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude))
        }
    }
}

// MARK: - 요청 DTO

private struct KakaoDirectionsRequestDTO: Encodable {
    struct Point: Encodable {
        /// 카카오는 경도를 x, 위도를 y로 씁니다. 순서를 바꿔 쓰지 않도록 여기서만 변환합니다.
        let x: Double
        let y: Double

        init(_ coordinate: CLLocationCoordinate2D) {
            x = coordinate.longitude
            y = coordinate.latitude
        }
    }

    let origin: Point
    let destination: Point
    let waypoints: [Point]?
    let priority: String
    let alternatives: Bool
    let roadDetails: Bool

    enum CodingKeys: String, CodingKey {
        case origin, destination, waypoints, priority, alternatives
        case roadDetails = "road_details"
    }
}

// MARK: - 응답 DTO

private struct KakaoGatewayErrorDTO: Decodable {
    let message: String?
    let msg: String?
    let errorType: String?

    var displayMessage: String? {
        message ?? msg ?? errorType
    }
}

private struct KakaoDirectionsResponseDTO: Decodable {
    let routes: [Route]

    struct Route: Decodable {
        let resultCode: Int
        let resultMessage: String?
        let summary: Summary?
        let sections: [Section]?

        enum CodingKeys: String, CodingKey {
            case resultCode = "result_code"
            case resultMessage = "result_msg"
            case summary, sections
        }

        /// 카카오 응답을 화면이 쓰는 RouteDirections로 옮깁니다.
        /// - Parameters:
        ///   - waypoints: 요청에 실제로 보낸 경유지입니다. 구간의 도착 지점을 채우는 데 씁니다.
        ///   - destination: 마지막 구간의 도착 지점입니다.
        func toDomain(
            waypoints: [CLLocationCoordinate2D],
            destination: CLLocationCoordinate2D
        ) -> RouteDirections? {
            guard let summary, let sections, !sections.isEmpty else { return nil }

            var path: [CLLocationCoordinate2D] = []
            var legs: [RouteLeg] = []

            for (index, section) in sections.enumerated() {
                for road in section.roads ?? [] {
                    for coordinate in road.coordinates {
                        // 도로와 도로가 만나는 지점은 양쪽에 중복으로 들어옵니다.
                        // 그대로 두면 경로선에 같은 점이 두 번 찍히므로 이어붙일 때 걸러 냅니다.
                        if let last = path.last,
                           last.latitude == coordinate.latitude,
                           last.longitude == coordinate.longitude {
                            continue
                        }
                        path.append(coordinate)
                    }
                }

                // sections는 항상 "경유지 수 + 1"개이고 순서대로 들어옵니다.
                // 마지막 구간만 목적지로 향하고, 나머지는 같은 순서의 경유지로 향합니다.
                let legDestination = index < waypoints.count ? waypoints[index] : destination

                legs.append(
                    RouteLeg(
                        destination: legDestination,
                        distanceMeters: section.distance ?? 0,
                        // 카카오는 초 단위입니다. 네이버(밀리초)와 달라 나누지 않습니다.
                        duration: TimeInterval(section.duration ?? 0),
                        pathEndIndex: max(path.count - 1, 0)
                    )
                )
            }

            guard !path.isEmpty else { return nil }

            return RouteDirections(
                distanceMeters: summary.distance,
                duration: TimeInterval(summary.duration),
                path: path,
                legs: legs
            )
        }
    }

    struct Summary: Decodable {
        /// 총 이동 거리(m)
        let distance: Int
        /// 총 소요 시간(초)
        let duration: Int
    }

    struct Section: Decodable {
        let distance: Int?
        let duration: Int?
        let roads: [Road]?
    }

    struct Road: Decodable {
        /// [경도, 위도, 경도, 위도, …] 형태로 한 줄에 펴서 내려옵니다.
        let vertexes: [Double]?

        var coordinates: [CLLocationCoordinate2D] {
            guard let vertexes else { return [] }
            return stride(from: 0, to: vertexes.count - 1, by: 2).map { index in
                CLLocationCoordinate2D(latitude: vertexes[index + 1], longitude: vertexes[index])
            }
        }
    }
}
