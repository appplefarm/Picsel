//
//  PhotoExploreLoadingWave.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/14/26.
//

import SwiftUI

/// 표면의 굴곡과 명암으로 깊이감을 표현하는 2.5D 물결입니다. 시간은 부모가 전달합니다.
struct PhotoExploreLoadingWave: View {
    let phase: Double

    private let gridSize = 5
    private let movementAmplitude = SIMD2<Double>(0.036, 0.084)
    private let background = Color(.systemBackground)

    var body: some View {
        let vertices = makeVertices()

        MeshGradient(
            width: gridSize,
            height: gridSize,
            points: vertices.map(\.position),
            colors: vertices.map(\.color),
            background: background,
            smoothsColors: true
        )
    }

    private func makeVertices() -> [Vertex] {
        // 한 바퀴의 끝을 시작과 같은 위상으로 계산합니다. sin/cos는 속도도 이어집니다.
        let phase = phase.truncatingRemainder(dividingBy: 2 * .pi)

        return (0..<(gridSize * gridSize)).map { index in
            let x = Double(index % gridSize) / Double(gridSize - 1)
            let y = Double(index / gridSize) / Double(gridSize - 1)

            // 가장자리는 위치와 색을 고정해 빈틈 없이 배경으로 스며들게 합니다.
            guard x > 0, x < 1, y > 0, y < 1 else {
                return Vertex(position: SIMD2(Float(x), Float(y)), color: background)
            }

            let envelope = sin(.pi * x) * sin(.pi * y)
            let wave = 2 * .pi * (1.25 * x + 0.45 * y) - phase
            let horizontal = cos(wave)
            let vertical = sin(wave)

            // 두 축을 1/4주기 어긋나게 움직여 동시에 멈추지 않고 순환합니다.
            let position = SIMD2(
                Float(x + envelope * movementAmplitude.x * horizontal),
                Float(y + envelope * movementAmplitude.y * vertical)
            )

            // 중앙 민트는 진하게 유지하고, 명암만 살짝 흘려 깊이감을 만듭니다.
            let centerTint = 0.48 * envelope * envelope
            let tintAmount = envelope * (0.28 + 0.12 * horizontal) + centerTint

            return Vertex(
                position: position,
                color: background.mix(with: PicselColor.photoLoadingWaveTint, by: tintAmount)
            )
        }
    }

    private struct Vertex {
        let position: SIMD2<Float>
        let color: Color
    }
}
