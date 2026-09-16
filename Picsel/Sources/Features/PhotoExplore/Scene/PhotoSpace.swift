//
//  PhotoSpace.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import Foundation

/// 2D 배치값을 RealityKit 공간으로 옮길 때 사용하는 공통 기준입니다.
enum PhotoSpace {
    static let focusDistance: Float = 3
    /// 시작·화면 맞춤은 초점 위치보다 카메라를 50% 뒤로 두어 공간을 넓게 보여줍니다.
    static let initialCameraDistance = focusDistance * 1.50
    static let sharpDepthTolerance: Float = 0.25
    static let focusFadeRange: Float = 1.55
    /// 초점 사진의 긴 변은 화면의 짧은 변 기준 70%로 통일합니다.
    static let focusedPhotoViewportFraction: Float = 0.70
    static let verticalFieldOfViewDegrees: Float = 55
    /// 공간에 배치하는 모든 사진의 긴 변입니다. 배치 좌표와 같은 단위를 사용합니다.
    static let photoLongEdgePoints: Float = 220

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

    /// 가로형·세로형 모두 같은 긴 변 안에 원본 비율 그대로 맞춥니다.
    static func photoSize(aspectRatio: Float) -> SIMD2<Float> {
        let ratio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1
        let longEdge = photoLongEdgePoints / worldPointScale
        return SIMD2(
            longEdge * min(ratio, 1),
            longEdge / max(ratio, 1)
        )
    }

    /// 초점 영역에 진입할 때 크기와 기울기가 튀지 않게 보정량을 연결합니다.
    static func focusProgress(depthError: Float) -> Float {
        let progress = min(max(
            (depthError - sharpDepthTolerance)
                / (selectionDepthTolerance - sharpDepthTolerance),
            0
        ), 1)
        return 1 - progress * progress * (3 - 2 * progress)
    }

    /// 원본 비율을 유지하며 같은 화면 영역에 들어가는 균일 배율입니다.
    static func focusedScale(
        photoSize: SIMD2<Float>,
        forwardDepth: Float,
        viewportSize: CGSize
    ) -> Float? {
        guard viewportSize.width > 0, viewportSize.height > 0,
              photoSize.x > 0, photoSize.y > 0, forwardDepth > 0 else { return nil }

        let aspectRatio = Float(viewportSize.width / viewportSize.height)
        let verticalSpan = verticalSpanAtFocus * forwardDepth / focusDistance
        let targetSide = verticalSpan * min(aspectRatio, 1) * focusedPhotoViewportFraction
        return targetSide / max(photoSize.x, photoSize.y)
    }
}
