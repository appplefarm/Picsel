//
//  SpatialPlaceItem.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import CoreGraphics
import Foundation

/// `PhotoDestination`에 공간 탐색 화면의 배치만 결합한 화면 전용 모델입니다.
/// 선택 결과로는 이 타입이 아닌 `PhotoDestination`을 전달합니다.
struct SpatialPlaceItem: Identifiable, Hashable {
    let destination: PhotoDestination
    private let placement: SpatialPlacePlacement

    var id: PhotoDestination.ID { destination.id }
    var name: String { destination.name }
    var imageURL: URL? { destination.photoURL.flatMap(URL.init(string:)) }
    var position: CGPoint { placement.position }
    var size: CGSize { placement.size }
    var fallbackAspectRatio: CGFloat {
        size.height > 0 ? size.width / size.height : 1
    }
    var depth: CGFloat { placement.depth }
    var yaw: Double { placement.yaw }
}

private struct SpatialPlacePlacement: Hashable {
    let position: CGPoint
    let size: CGSize
    /// 0...1. 클수록 사용자에게 가까운 레이어입니다.
    let depth: CGFloat
    let yaw: Double
}

extension SpatialPlaceItem {
    static let displayLimit = layout.count

    /// API가 변환한 후보 순서대로 사진 공간에 배치합니다.
    static func compose(
        from destinations: [PhotoDestination]
    ) -> [SpatialPlaceItem] {
        zip(destinations.prefix(layout.count), layout).map {
            SpatialPlaceItem(destination: $0.0, placement: $0.1)
        }
    }

    private static let layout: [SpatialPlacePlacement] = [
        SpatialPlacePlacement(
            position: CGPoint(x: 94, y: 13),
            size: CGSize(width: 172, height: 247),
            depth: 0.78,
            yaw: -15
        ),
        SpatialPlacePlacement(
            position: CGPoint(x: -206, y: -72),
            size: CGSize(width: 196, height: 186),
            depth: 0.72,
            yaw: 34
        ),
        SpatialPlacePlacement(
            position: CGPoint(x: 180, y: -240),
            size: CGSize(width: 124, height: 213),
            depth: 0.63,
            yaw: -38
        ),
        SpatialPlacePlacement(
            position: CGPoint(x: 234, y: 283),
            size: CGSize(width: 184, height: 188),
            depth: 0.57,
            yaw: -30
        ),
        SpatialPlacePlacement(
            position: CGPoint(x: -200, y: 216),
            size: CGSize(width: 152, height: 202),
            depth: 0.76,
            yaw: 31
        ),
        SpatialPlacePlacement(
            position: CGPoint(x: -15, y: 360),
            size: CGSize(width: 220, height: 126),
            depth: 0.52,
            yaw: 0
        ),
        SpatialPlacePlacement(
            position: CGPoint(x: -100, y: -293),
            size: CGSize(width: 148, height: 214),
            depth: 0.52,
            yaw: 12
        )
//        SpatialPlacePlacement(
//            position: CGPoint(x: 253, y: -60),
//            size: CGSize(width: 194, height: 138),
//            depth: 0.48,
//            yaw: -44
//        ),
//        SpatialPlacePlacement(
//            position: CGPoint(x: -286, y: -400),
//            size: CGSize(width: 168, height: 116),
//            depth: 0.32,
//            yaw: 27
//        ),
//        SpatialPlacePlacement(
//            position: CGPoint(x: 40, y: 328),
//            size: CGSize(width: 50, height: 280),
//            depth: 0.12,
//            yaw: -33
//        )
    ]
}
