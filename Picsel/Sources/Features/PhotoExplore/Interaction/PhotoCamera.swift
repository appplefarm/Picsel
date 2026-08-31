//
//  PhotoCamera.swift
//  Picsel
//

import CoreGraphics
import Foundation

/// 제스처가 종료된 후 유지되는 카메라 위치입니다.
struct PhotoCameraState: Equatable {
    static let initial = PhotoCameraState(
        position: SIMD3<Float>(0, 0, PhotoSpace.focusDistance)
    )

    var position: SIMD3<Float>

    func applying(
        _ gesture: PhotoCameraGesture,
        in viewportSize: CGSize,
        settings: PhotoInteractionSettings
    ) -> Self {
        let viewportHeight = max(Float(viewportSize.height), 1)
        let worldUnitsPerPoint = PhotoSpace.verticalSpanAtFocus
            / viewportHeight
            * Float(settings.dragSensitivity)
        let magnification = max(Float(gesture.magnification), 0.01)
        let zoomDelta = log2(magnification) * Float(settings.zoomSensitivity)
        let nextZ = (position.z - zoomDelta)
            .clamped(to: PhotoSpace.depthRange)

        var nextPosition = SIMD3<Float>(
            position.x - (Float(gesture.translation.width) * worldUnitsPerPoint),
            position.y + (Float(gesture.translation.height) * worldUnitsPerPoint),
            nextZ
        )

        nextPosition.x = nextPosition.x.clamped(to: PhotoSpace.lateralRange)
        nextPosition.y = nextPosition.y.clamped(to: PhotoSpace.lateralRange)

        return Self(position: nextPosition)
    }

    func depthError(to itemPosition: SIMD3<Float>) -> Float {
        abs((position.z - itemPosition.z) - PhotoSpace.focusDistance)
    }

    func focused(on itemPosition: SIMD3<Float>) -> Self {
        Self(
            position: SIMD3<Float>(
                itemPosition.x.clamped(to: PhotoSpace.lateralRange),
                itemPosition.y.clamped(to: PhotoSpace.lateralRange),
                (itemPosition.z + PhotoSpace.focusDistance)
                    .clamped(to: PhotoSpace.depthRange)
            )
        )
    }

}

/// 한 번의 드래그·핀치에서 누적되는 카메라 입력값입니다.
struct PhotoCameraGesture {
    var translation: CGSize = .zero
    var predictedTranslation: CGSize = .zero
    var magnification: CGFloat = 1
    var magnificationVelocity: CGFloat = 0

    mutating func merge(_ update: PhotoCameraGestureUpdate) {
        if let translation = update.translation {
            self.translation = translation
        }
        if let predictedTranslation = update.predictedTranslation {
            self.predictedTranslation = predictedTranslation
        }
        if let magnification = update.magnification {
            self.magnification = magnification
        }
        if let magnificationVelocity = update.magnificationVelocity {
            self.magnificationVelocity = magnificationVelocity
        }
    }

    func projected(using settings: PhotoInteractionSettings) -> Self {
        var result = self
        result.translation = translation.projected(
            toward: predictedTranslation,
            retention: CGFloat(settings.dragMomentumRetention),
            maximumDistance: CGFloat(settings.maximumDragCoast)
        )

        let zoomFactor = exp(
            magnificationVelocity * CGFloat(settings.zoomMomentumDuration)
        )
        let maximumZoomCoast = CGFloat(settings.maximumZoomCoast)
        let zoomFactorRange = ClosedRange<CGFloat>(
            uncheckedBounds: (
                lower: 1 / (1 + maximumZoomCoast),
                upper: 1 + maximumZoomCoast
            )
        )
        result.magnification *= zoomFactor.clamped(to: zoomFactorRange)
        return result
    }
}

/// 복합 제스처에서 이번 이벤트에 실제로 들어온 값만 전달합니다.
struct PhotoCameraGestureUpdate {
    var translation: CGSize?
    var predictedTranslation: CGSize?
    var magnification: CGFloat?
    var magnificationVelocity: CGFloat?
}

private extension CGSize {
    func projected(
        toward prediction: CGSize,
        retention: CGFloat,
        maximumDistance: CGFloat
    ) -> CGSize {
        var coast = CGSize(
            width: (prediction.width - width) * retention,
            height: (prediction.height - height) * retention
        )
        let distance = hypot(coast.width, coast.height)

        if distance > maximumDistance {
            let scale = maximumDistance / distance
            coast.width *= scale
            coast.height *= scale
        }

        return CGSize(
            width: width + coast.width,
            height: height + coast.height
        )
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
