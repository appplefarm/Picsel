//
//  PhotoExploreLoadingView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/14/26.
//

import SwiftUI

/// 사진 탐색 준비 중에 표시할 화면입니다. 데이터 로딩이나 화면 전환은 부모가 담당합니다.
struct PhotoExploreLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .subheadline) private var messageFontSize = 14

    private let waveDuration = 8.0

    var body: some View {
        GeometryReader { geometry in
            let waveSize = min(geometry.size.width * 1.2, geometry.size.height * 0.65)

            ZStack {
                Color(.systemBackground)

                animatedWave
                    .frame(width: waveSize, height: waveSize)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .overlay(alignment: .bottom) {
                Text("사진을 공간에 펼치는 중이에요...")
                    .font(.system(size: messageFontSize))
                    .foregroundStyle(PicselColor.photoLoadingText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(32, geometry.size.height * 0.16))
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var animatedWave: some View {
        if reduceMotion || scenePhase != .active {
            PhotoExploreLoadingWave(phase: 0)
        } else {
            // 로딩 작업과 자원을 나누므로 갱신은 최대 30fps로 제한합니다.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                // 시간은 일정하게 진행합니다. 반복 경계에 감속이나 역재생을 넣지 않습니다.
                let progress = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: waveDuration) / waveDuration
                let phase = progress * 2 * .pi

                PhotoExploreLoadingWave(phase: phase)
            }
        }
    }
}
