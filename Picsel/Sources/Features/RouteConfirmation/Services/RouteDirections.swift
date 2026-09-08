//
//  RouteDirections.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import CoreLocation
import Foundation

/// 경로 계산 결과를 담는 도메인 모델입니다.
/// 특정 지도 업체에 의존하지 않도록 응답 형식과 분리해 둡니다.
struct RouteDirections: Equatable {
    /// 총 이동 거리(m)
    let distanceMeters: Int
    /// 총 소요 시간(초)
    let duration: TimeInterval
    /// 지도에 그릴 경로 좌표입니다.
    let path: [CLLocationCoordinate2D]
    /// 출발지 → 경유지1 → … → 목적지 사이의 구간 목록입니다.
    /// 항상 `경유지 수 + 1`개이며, 마지막 구간이 목적지로 향하는 구간입니다.
    let legs: [RouteLeg]

    static func == (lhs: RouteDirections, rhs: RouteDirections) -> Bool {
        lhs.distanceMeters == rhs.distanceMeters
            && lhs.duration == rhs.duration
            && lhs.legs == rhs.legs
            && lhs.path.count == rhs.path.count
    }
}

/// 지점과 지점 사이 한 구간입니다.
struct RouteLeg: Equatable {
    /// 이 구간의 도착 지점 좌표입니다.
    let destination: CLLocationCoordinate2D
    let distanceMeters: Int
    let duration: TimeInterval
    /// 전체 path 배열에서 이 구간이 끝나는 위치입니다. 구간별로 경로를 잘라 쓸 때 사용합니다.
    let pathEndIndex: Int

    var durationMinutes: Int {
        max(1, Int((duration / 60).rounded()))
    }

    static func == (lhs: RouteLeg, rhs: RouteLeg) -> Bool {
        lhs.distanceMeters == rhs.distanceMeters
            && lhs.duration == rhs.duration
            && lhs.pathEndIndex == rhs.pathEndIndex
    }
}

/// 경로를 계산해 주는 서비스입니다.
/// 업체를 바꿔도 화면 코드가 그대로이도록 프로토콜로 감쌉니다.
protocol RouteDirectionsProviding: Sendable {
    func directions(
        origin: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) async throws -> RouteDirections
}

enum RouteDirectionsError: LocalizedError {
    /// Secrets.xcconfig에 키가 없거나 Info.plist로 전달되지 않은 경우입니다.
    case missingAPIKey
    case invalidRequest
    case networkFailure(underlying: Error)
    /// 업체가 내려준 에러 코드입니다.
    case providerError(code: String, message: String)
    /// 요청은 성공했지만 경로를 찾지 못한 경우입니다.
    case routeNotFound

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "지도 API 키를 불러오지 못했어요."
        case .invalidRequest:
            "경로 요청을 만들지 못했어요."
        case .networkFailure:
            "네트워크 상태를 확인해 주세요."
        case .providerError(_, let message):
            message
        case .routeNotFound:
            "이 경로는 길찾기를 지원하지 않아요."
        }
    }
}
