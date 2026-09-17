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

    var body: some View {
        GeometryReader { geometry in
            let videoHeight = min(geometry.size.width * 4 / 3, geometry.size.height * 0.65)

            ZStack {
                PicselColor.photoLoadingBackground

                loadingVisual
                    .frame(width: videoHeight * 3 / 4, height: videoHeight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .overlay(alignment: .bottom) {
                Text("사진을 공간에 펼치는 중이에요...")
                    .font(PicselFont.body01)
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
    private var loadingVisual: some View {
        ZStack {
            // 첫 프레임 준비 전·재생 실패·동작 줄이기에서는 빈 화면 대신 같은 정지 이미지를 표시합니다.
            Image("PhotoExploreLoadingPoster")
                .resizable()
                .scaledToFit()

            if !reduceMotion {
                PhotoExploreLoadingVideo(isPlaying: scenePhase == .active)
            }
        }
    }
}
