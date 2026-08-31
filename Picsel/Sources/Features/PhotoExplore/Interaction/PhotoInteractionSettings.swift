//
//  PhotoInteractionSettings.swift
//  Picsel
//

import Foundation

/// 공간 사진 조작을 실행 중에 튜닝하기 위한 값입니다.
struct PhotoInteractionSettings: Equatable {
    static let defaults = Self()

    // Apple gesture recognition
    var dragStartDistance = 0.0
    var pinchStartDelta = 0.001

    // Direct manipulation
    var dragSensitivity = 1.0
    var zoomSensitivity = 1.0

    // Momentum
    var dragMomentumRetention = 0.24
    var maximumDragCoast = 110.0
    var zoomMomentumDuration = 0.045
    var maximumZoomCoast = 0.12
    var settlingDuration = 0.26

    // Magnet and appearance
    var magnetDepthTolerance = 0.38
    var magnetViewportMargin = 0.55
    var photoScale = 1.5
}
