//
//  NaverDirectionsService.swift
//  Picsel
//

import CoreLocation
import Foundation

/// 네이버 클라우드 플랫폼 Directions 15로 자동차 경로를 계산합니다.
///
/// Google Maps는 국내 규제로 자동차 길찾기를 제공하지 않아 국내 서비스를 사용합니다.
/// 응답을 그대로 노출하지 않고 RouteDirections로 변환해 화면에서 업체를 몰라도 되게 합니다.
struct NaverDirectionsService: RouteDirectionsProviding {

    /// Directions 15가 한 번에 받을 수 있는 경유지 수입니다.
    static let maximumWaypointCount = 15

    private let session: URLSession
    private let baseURL = URL(string: "https://maps.apigw.ntruss.com/map-direction-15/v1/driving")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func directions(
        origin: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) async throws -> RouteDirections {
        let request = try makeRequest(
            origin: origin,
            waypoints: Array(waypoints.prefix(Self.maximumWaypointCount)),
            destination: destination
        )

        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw RouteDirectionsError.networkFailure(underlying: error)
        }

        // 인증 실패나 미구독은 route 없이 error 객체만 내려옵니다.
        if let failure = try? JSONDecoder().decode(NaverDirectionsErrorDTO.self, from: data),
           let error = failure.error {
            throw RouteDirectionsError.providerError(
                code: error.errorCode,
                message: error.message
            )
        }

        let response = try JSONDecoder().decode(NaverDirectionsResponseDTO.self, from: data)

        guard response.code == 0 else {
            throw RouteDirectionsError.providerError(
                code: String(response.code),
                message: response.message ?? "경로를 계산하지 못했어요."
            )
        }

        guard let route = response.route?.trafast?.first else {
            throw RouteDirectionsError.routeNotFound
        }

        return route.toDomain()
    }

    private func makeRequest(
        origin: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw RouteDirectionsError.invalidRequest
        }

        var queryItems = [
            URLQueryItem(name: "start", value: Self.parameter(from: origin)),
            URLQueryItem(name: "goal", value: Self.parameter(from: destination)),
            // trafast: 실시간 빠른 길. 내비 앱이 안내하는 경로와 성격이 가장 가깝습니다.
            URLQueryItem(name: "option", value: "trafast")
        ]

        if !waypoints.isEmpty {
            let value = waypoints.map(Self.parameter(from:)).joined(separator: "|")
            queryItems.append(URLQueryItem(name: "waypoints", value: value))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw RouteDirectionsError.invalidRequest
        }

        guard
            let clientID = Bundle.main.object(forInfoDictionaryKey: "NAVER_MAPS_CLIENT_ID") as? String,
            let clientSecret = Bundle.main.object(forInfoDictionaryKey: "NAVER_MAPS_CLIENT_SECRET") as? String,
            !clientID.isEmpty, !clientSecret.isEmpty,
            !clientID.contains("$("), !clientSecret.contains("$(")
        else {
            throw RouteDirectionsError.missingAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(clientID, forHTTPHeaderField: "x-ncp-apigw-api-key-id")
        request.setValue(clientSecret, forHTTPHeaderField: "x-ncp-apigw-api-key")
        return request
    }

    /// 네이버는 "경도,위도" 순서를 사용합니다. 위경도 순서를 바꿔 쓰지 않도록 한곳에서만 만듭니다.
    private static func parameter(from coordinate: CLLocationCoordinate2D) -> String {
        "\(coordinate.longitude),\(coordinate.latitude)"
    }
}

// MARK: - 응답 DTO

private struct NaverDirectionsErrorDTO: Decodable {
    struct Body: Decodable {
        let errorCode: String
        let message: String
    }

    let error: Body?
}

private struct NaverDirectionsResponseDTO: Decodable {
    let code: Int
    let message: String?
    let route: Route?

    struct Route: Decodable {
        let trafast: [Path]?
    }

    struct Path: Decodable {
        let summary: Summary
        /// [[경도, 위도], …]
        let path: [[Double]]

        func toDomain() -> RouteDirections {
            let coordinates = path.compactMap { point -> CLLocationCoordinate2D? in
                guard point.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
            }

            // waypoints와 goal 모두 "직전 지점부터 이 지점까지"의 값을 담고 있습니다.
            let legs = (summary.waypoints ?? []).map { $0.toLeg() } + [summary.goal.toLeg()]

            return RouteDirections(
                distanceMeters: summary.distance,
                duration: TimeInterval(summary.duration) / 1_000,
                path: coordinates,
                legs: legs
            )
        }
    }

    struct Summary: Decodable {
        let distance: Int
        /// 밀리초 단위입니다.
        let duration: Int
        let waypoints: [Point]?
        let goal: Point
    }

    struct Point: Decodable {
        let location: [Double]
        let distance: Int?
        let duration: Int?
        let pointIndex: Int?

        func toLeg() -> RouteLeg {
            RouteLeg(
                destination: CLLocationCoordinate2D(
                    latitude: location.count >= 2 ? location[1] : 0,
                    longitude: location.first ?? 0
                ),
                distanceMeters: distance ?? 0,
                duration: TimeInterval(duration ?? 0) / 1_000,
                pathEndIndex: pointIndex ?? 0
            )
        }
    }
}
