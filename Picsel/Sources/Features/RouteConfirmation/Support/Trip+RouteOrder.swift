//
//  Trip+RouteOrder.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import Foundation

extension Trip {
    /// 경유지 → 최종 목적지 순서로 정렬한 경로입니다.
    ///
    /// `RouteStop`에는 순서를 저장하는 필드가 없어 배열 순서가 유일한 기준인데,
    /// 목적지는 여행 생성 시점에 가장 먼저 추가되고 경유지는 그 뒤에 붙습니다.
    /// 화면과 경로 계산은 항상 "목적지가 마지막"이어야 하므로 이 계산 속성을 통해 접근합니다.
    var orderedStops: [RouteStop] {
        stops.filter { !$0.isDestination } + stops.filter(\.isDestination)
    }

    /// 최종 목적지입니다. 아직 선택되지 않았다면 nil입니다.
    var destinationStop: RouteStop? {
        stops.first(where: \.isDestination)
    }

    /// 목적지를 제외한 경유지 목록입니다.
    var waypointStops: [RouteStop] {
        stops.filter { !$0.isDestination }
    }
}
