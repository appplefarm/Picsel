//
//  PhotoInteractionSettings.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
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
    var dragMomentumRetention = 0.40
    var maximumDragCoast = 160.0
    var zoomMomentumDuration = 0.10
    var maximumZoomCoast = 0.22
    var settlingDuration = 0.40

    // Magnet and appearance
    var magnetDepthTolerance = 0.60
    var magnetViewportMargin = 0.55
    // 하이파이 기준: 가까운 가로 사진은 화면 너비의 약 2/3를 차지합니다.
    var photoScale = 1.2
}
