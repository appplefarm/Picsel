//
//  PixelUnlockedView.swift
//  Picsel
//
//  18_픽셀_획득 — "새로운 픽셀이 채워졌어요!"
//  저장 직후 결과 화면.
//

import SwiftData
import SwiftUI

struct PixelUnlockedView: View {

    let snapshot: TripRecordSnapshot

    /// 이번 여행으로 채운 칸입니다. 픽셀을 못 받은 여행이면 nil입니다.
    let unlockedRegionCode: String?

    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var pixels: [UserPixel]

    /// 전국 지도까지 펼쳐졌는지입니다.
    @State private var isMapRevealed = false
    /// 아래 버튼이 나타났는지입니다.
    @State private var areActionsVisible = false

    var body: some View {
        // 시안(402×874)의 절대 좌표를 옮긴 값입니다.
        // 제목은 위쪽, 버튼은 아래쪽에 고정하고 남는 공간을 지도 위아래로 나눕니다.
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 60)

            Spacer(minLength: 24)

            PixelUnlockedMapView(
                highlightedRegionCode: unlockedRegionCode,
                unlockedRegionCodes: previouslyUnlockedRegionCodes,
                isRevealed: isMapRevealed
            )
            .frame(maxWidth: .infinity)
            // 시안의 지도 이미지 높이입니다.
            .frame(height: 374)

            Spacer(minLength: 24)

            actionButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PicselColor.backgroundWarmWhite)
        .navigationBarBackButtonHidden(true)
        .task { await playIntro() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("새로운 픽셀이 채워졌어요!")
                .font(PicselFont.title02)
                .foregroundStyle(.black)

            Text("\(snapshot.regionName) 여행이 나의 픽셀 지도에 기록됐어요.")
                .font(PicselFont.body01)
                .foregroundStyle(PicselColor.textPrimary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 연출

    /// 채운 칸을 잠시 보여 준 뒤 전국으로 줌아웃하고, 마지막에 버튼을 띄웁니다.
    private func playIntro() async {
        // 이미 재생했다면 다시 하지 않습니다. (뒤로 갔다 돌아온 경우)
        guard !isMapRevealed else { return }

        // 강조할 칸이 없거나 사용자가 동작 줄이기를 켜 두었다면 결과만 바로 보여 줍니다.
        guard unlockedRegionCode != nil, !reduceMotion else {
            isMapRevealed = true
            areActionsVisible = true
            return
        }

        try? await Task.sleep(for: .milliseconds(Timing.holdOnPixel))
        withAnimation(.easeInOut(duration: Timing.zoomOutSeconds)) {
            isMapRevealed = true
        }

        try? await Task.sleep(for: .milliseconds(Timing.actionsDelay))
        withAnimation(.easeOut(duration: 0.35)) {
            areActionsVisible = true
        }
    }

    private enum Timing {
        /// 채운 칸 하나를 눈에 담을 시간
        static let holdOnPixel = 700
        /// 전국으로 빠지는 시간
        static let zoomOutSeconds: Double = 1.1
        /// 줌아웃이 끝난 뒤 버튼이 뜨기까지
        static let actionsDelay = 1_150
    }

    // MARK: - 버튼

    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button {
                router.finishTripFlow(returningTo: .home)
            } label: {
                Text("홈으로")
                    .font(PicselFont.label01)
                    .foregroundStyle(PicselColor.secondaryButtonText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(secondaryButtonBackground)
            }
            .buttonStyle(.plain)

            Button {
                router.finishTripFlow(returningTo: .picselMap)
            } label: {
                Text("픽셀맵 확인하기")
                    .font(PicselFont.label01)
            }
            .buttonStyle(.primaryGradient)
        }
        // 자리는 그대로 두고 나타나기만 해서 레이아웃이 흔들리지 않습니다.
        .opacity(areActionsVisible ? 1 : 0)
        .allowsHitTesting(areActionsVisible)
        .accessibilityHidden(!areActionsVisible)
    }

    private var secondaryButtonBackground: some View {
        RoundedRectangle(
            cornerRadius: 18,
            style: .continuous
        )
        .fill(PicselColor.secondaryButtonBackground)
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .strokeBorder(PicselColor.secondaryButtonBorder, lineWidth: 1)
        }
    }

    /// 이번에 채운 칸을 뺀 나머지입니다.
    /// 저장이 이미 끝난 뒤라 새 픽셀도 목록에 들어 있어, 강조 대상과 겹치지 않게 걸러 냅니다.
    private var previouslyUnlockedRegionCodes: Set<String> {
        var codes = Set(pixels.map { String($0.regionCode) })
        if let unlockedRegionCode {
            codes.remove(unlockedRegionCode)
        }
        return codes
    }
}

#Preview {
    NavigationStack {
        PixelUnlockedView(snapshot: .sample, unlockedRegionCode: "4711")
    }
    .environment(AppRouter())
    .modelContainer(
        for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self],
        inMemory: true
    )
}
