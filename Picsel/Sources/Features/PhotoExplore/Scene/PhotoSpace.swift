//
//  PhotoSpace.swift
//  Picsel
//

import Foundation

/// 2D 배치값을 RealityKit 공간으로 옮길 때 사용하는 공통 기준입니다.
enum PhotoSpace {
    static let focusDistance: Float = 3
    static let focusFadeRange: Float = 1.55
    static let verticalFieldOfViewDegrees: Float = 55

    static let selectionDepthTolerance: Float = 0.72
    static let selectionHysteresis: Float = 0.12
    static let selectionViewportMargin: Float = 1.25

    static let depthRange: ClosedRange<Float> = -1.35...4.25
    static let lateralRange: ClosedRange<Float> = -1.8...1.8

    private static let worldPointScale: Float = 190
    private static let depthScale: Float = 4.2

    static let verticalSpanAtFocus = 2 * focusDistance
        * tan(verticalFieldOfViewDegrees * .pi / 360)

    static func position(for item: SpatialPlaceItem) -> SIMD3<Float> {
        SIMD3<Float>(
            Float(item.position.x) / worldPointScale,
            -Float(item.position.y) / worldPointScale,
            (Float(item.depth) - 0.98) * depthScale
        )
    }

    static func width(for item: SpatialPlaceItem) -> Float {
        max(Float(item.size.width) / worldPointScale, 0.55)
    }

}
