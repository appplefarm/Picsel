//
//  PhotoSnapNavigation.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/17/26.
//

import CoreGraphics

/// 주변 고리와 중앙 연결점만 정의합니다. 사진 모델/좌표나 렌더링은 변경하지 않습니다.
struct PhotoSnapNavigation {
    private let ring = [2, 7, 3, 4, 6, 5]
    private let hub = 1

    func neighbors(of current: SpatialPlaceItem, among items: [SpatialPlaceItem]) -> [SpatialPlaceItem] {
        if current.placementNumber == hub { return items.filter { $0.id != current.id } }

        // 로드에 실패한 사진은 건너뛰되, 실제 배치 번호와 고리 순서는 유지합니다.
        let availableNumbers = Set(items.map(\.placementNumber))
        let availableRing = ring.filter { availableNumbers.contains($0) }
        guard let index = availableRing.firstIndex(of: current.placementNumber) else { return [] }
        let previous = availableRing[(index + availableRing.count - 1) % availableRing.count]
        let next = availableRing[(index + 1) % availableRing.count]
        let connected = Set([previous, next, hub])
        return items.filter { $0.id != current.id && connected.contains($0.placementNumber) }
    }

    /// 한 드래그에 한 이웃만 선택합니다. 깊이는 도착할 때 함께 맞춰 핀치가 필요 없게 합니다.
    func target(
        from current: SpatialPlaceItem,
        translation: CGSize,
        among items: [SpatialPlaceItem],
        minimumDistance: CGFloat
    ) -> SpatialPlaceItem {
        let distance = hypot(translation.width, translation.height)
        guard distance >= minimumDistance, distance > 0 else { return current }

        // 사진을 왼쪽으로 밀면 공간의 오른쪽 사진을 향합니다.
        let dx = -translation.width / distance
        let dy = -translation.height / distance
        return neighbors(of: current, among: items).compactMap { item -> (SpatialPlaceItem, CGFloat)? in
            let x = item.position.x - current.position.x
            let y = item.position.y - current.position.y
            let length = hypot(x, y)
            guard length > 0 else { return nil }
            let alignment = (dx * x + dy * y) / length
            guard alignment >= 0.45 else { return nil }
            return (item, alignment)
        }.max(by: { $0.1 < $1.1 })?.0 ?? current
    }
}
