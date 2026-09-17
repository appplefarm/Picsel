//
//  TravelPreparingBackground.swift
//  Picsel
//

import SwiftUI

/// Figma의 여행 준비 화면 배경을 Shape와 EllipticalGradient로 재현합니다.
/// 기준 캔버스는 402pt이며 다른 iPhone 폭에서는 동일한 비율로 확장됩니다.
struct TravelPreparingBackground: View {
    private let designWidth: CGFloat = 402

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth

            ZStack(alignment: .topLeading) {
                PicselColor.tripReadyBackground

                preparingGlow(
                    size: CGSize(width: 470.88751, height: 412.78198),
                    stops: Self.primaryStops,
                    opacity: 0.3,
                    cornerRadius: 470.88751,
                    scale: scale
                )
                .rotationEffect(.degrees(-0.89))
                .position(x: 307.625 * scale, y: 189.351 * scale)

                preparingGlow(
                    size: CGSize(width: 217, height: 181),
                    stops: Self.primaryStops,
                    opacity: 0.3,
                    scale: scale
                )
                .position(x: 419.5 * scale, y: 204.5 * scale)

                preparingGlow(
                    size: CGSize(width: 124, height: 60),
                    stops: Self.secondaryStops,
                    opacity: 0.4,
                    scale: scale
                )
                .position(x: 191 * scale, y: 33 * scale)

                preparingGlow(
                    size: CGSize(width: 217, height: 181),
                    stops: Self.primaryStops,
                    opacity: 0.3,
                    scale: scale
                )
                .position(x: 32.5 * scale, y: 585.5 * scale)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func preparingGlow(
        size: CGSize,
        stops: [Gradient.Stop],
        opacity: Double,
        cornerRadius: CGFloat = 0,
        scale: CGFloat
    ) -> some View {
        Rectangle()
            .foregroundStyle(.clear)
            .frame(width: size.width * scale, height: size.height * scale)
            .background(
                EllipticalGradient(
                    stops: stops,
                    center: .center
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius * scale,
                    style: .continuous
                )
            )
            .opacity(opacity)
            .blur(radius: 37.5 * scale)
    }

    private static let primaryStops: [Gradient.Stop] = [
        .init(
            color: Color(red: 0, green: 0.84, blue: 0.69).opacity(0.8),
            location: 0
        ),
        .init(
            color: Color(red: 0, green: 0.56, blue: 0.51).opacity(0.4),
            location: 0.737445
        ),
        .init(
            color: Color(red: 0, green: 0.56, blue: 0.51).opacity(0),
            location: 1
        )
    ]

    private static let secondaryStops: [Gradient.Stop] = [
        .init(
            color: Color(red: 0, green: 0.84, blue: 0.69).opacity(0.8),
            location: 0
        ),
        .init(
            color: Color(red: 0.52, green: 0.92, blue: 0.53).opacity(0.45),
            location: 0.682692
        ),
        .init(
            color: Color(red: 0, green: 0.56, blue: 0.51).opacity(0),
            location: 1
        )
    ]
}

#Preview {
    TravelPreparingBackground()
}
