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

    /// 표시용 소요 시간(분)입니다.
    ///
    /// 업체가 이 구간의 시간을 주지 않으면 0이 들어옵니다.
    /// 예전에는 max(1, …)이 그 0을 "1분"으로 바꿔 버려서,
    /// 데이터가 없다는 사실이 그럴듯한 숫자에 가려졌습니다.
    /// 값이 없으면 nil을 돌려주고 화면에서 배지를 감춥니다.
    var durationMinutes: Int? {
        guard duration > 0 else { return nil }
        return max(1, Int((duration / 60).rounded()))
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
    /// 업체가 허용하는 총 경로 길이를 넘은 경우입니다.
    case routeTooLong
    /// 경유지 주변에 자동차로 갈 수 있는 도로가 없는 경우입니다.
    ///
    /// 관광 API가 주는 좌표에는 산·해상·등산로처럼 도로에서 떨어진 지점이 섞입니다.
    /// 좌표가 바뀌지 않는 한 몇 번을 보내도 같은 대답이 오므로,
    /// 잠시 후 다시 해보면 되는 실패와 구분해서 다룹니다.
    case unreachableWaypoint

    var requestFailure: RequestFailure {
        switch self {
        case .networkFailure(let error): RequestFailure(error)
        case .missingAPIKey, .invalidRequest: .configuration
        case .providerError: .server
        case .routeNotFound, .routeTooLong: .unavailable
        case .unreachableWaypoint: .unreachableWaypoint
        }
    }

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
        case .routeTooLong:
            "경로가 너무 길어요. 목적지나 경유지를 줄여 주세요."
        case .unreachableWaypoint:
            "자동차로 갈 수 없는 장소가 있어요."
        }
    }
}
