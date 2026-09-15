//
//  TripInProgressHomeView.swift
//  Picsel
//

import SwiftUI

/// 여행이 진행 중일 때 사용하는 대체 홈 화면입니다.
///
/// 현재 홈 흐름에는 연결하지 않았으며, 상위 화면에서 필요한 동작만 Closure로 전달받습니다.
struct TripInProgressHomeView: View {
    let cityName: String
    /// 여행 완료 시 PixelUnlockedView에서 강조할 행정구역 코드와 같은 값입니다.
    let regionCode: String?
    let onSettingsTapped: () -> Void
    let onTripProgressTapped: () -> Void

    init(
        cityName: String = "포항",
        regionCode: String? = "4711",
        onSettingsTapped: @escaping () -> Void = {},
        onTripProgressTapped: @escaping () -> Void = {}
    ) {
        self.cityName = cityName
        self.regionCode = regionCode
        self.onSettingsTapped = onSettingsTapped
        self.onTripProgressTapped = onTripProgressTapped
    }

    var body: some View {
        ZStack {
            TripInProgressBackground()

            VStack(spacing: 0) {
                settingsButton

                titleSection
                    .padding(.top, Metric.titleTopSpacing)

                Spacer(minLength: Metric.titleToPixelMinimumSpacing)

                pixelView

                Spacer(minLength: Metric.pixelToButtonMinimumSpacing)

                progressButton
                    .padding(.bottom, Metric.bottomSpacing)
            }
            .padding(.horizontal, Metric.horizontalPadding)
        }
        .preferredColorScheme(.dark)
    }

    private var settingsButton: some View {
        HStack {
            Spacer()

            Button(action: onSettingsTapped) {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(PicselColor.tripHomeBackground)
                    .frame(width: Metric.settingsButtonSize, height: Metric.settingsButtonSize)
            }
            .background(.thinMaterial, in: Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.55), lineWidth: 0.5)
            }
            .contentShape(Circle())
            .accessibilityLabel("설정")
        }
        .padding(.top, Metric.settingsTopSpacing)
    }

    @ViewBuilder
    private var pixelView: some View {
        if let regionCode {
            PixelUnlockedMapView(
                highlightedRegionCode: regionCode,
                isRevealed: false
            )
            .frame(width: Metric.pixelWidth, height: Metric.pixelHeight)
            .shadow(color: PicselColor.tripHomeGlow.opacity(0.85), radius: 14)
            .accessibilityHidden(true)
        } else {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 92, weight: .light))
                .foregroundStyle(PicselColor.tripHomeSubtitle.opacity(0.8))
                .frame(width: Metric.pixelWidth, height: Metric.pixelHeight)
                .shadow(color: PicselColor.tripHomeGlow.opacity(0.7), radius: 14)
                .accessibilityHidden(true)
        }
    }

    private var titleSection: some View {
        VStack(spacing: 10) {
            Text("\(cityName) 여행 중")
                .font(PicselFont.title01)
                .foregroundStyle(PicselColor.tripHomeTitle)

            Text("이번 여행이 하나의 픽셀로 남아요")
                .font(PicselFont.subtitle01)
                .foregroundStyle(PicselColor.tripHomeSubtitle)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var progressButton: some View {
        Button(action: onTripProgressTapped) {
            HStack(spacing: 10) {
                Text("여행이 진행중이에요")
                    .font(PicselFont.label01)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(PicselColor.tripHomeTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .frame(height: Metric.progressButtonHeight)
            .background(
                LinearGradient(
                    stops: [
                        .init(color: PicselColor.tripHomeButtonStart, location: 0),
                        .init(color: PicselColor.tripHomeButtonStart, location: 0.60),
                        .init(color: PicselColor.tripHomeButtonEnd, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: .black.opacity(0.25), radius: 2, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint("진행 중인 여행 화면을 엽니다")
    }
}

private struct TripInProgressBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PicselColor.tripHomeBackground

                Ellipse()
                    .fill(PicselColor.tripHomeGlow.opacity(0.23))
                    .frame(width: proxy.size.width * 1.18, height: proxy.size.height * 0.48)
                    .blur(radius: 72)
                    .rotationEffect(.degrees(-1))
                    .offset(x: proxy.size.width * 0.22, y: -proxy.size.height * 0.38)

                Circle()
                    .fill(PicselColor.tripHomeGlow.opacity(0.18))
                    .frame(width: proxy.size.width * 0.54)
                    .blur(radius: 64)
                    .offset(x: proxy.size.width * 0.44, y: -proxy.size.height * 0.30)

                Circle()
                    .fill(PicselColor.tripHomeGlow.opacity(0.13))
                    .frame(width: proxy.size.width * 0.54)
                    .blur(radius: 70)
                    .offset(x: -proxy.size.width * 0.42, y: proxy.size.height * 0.20)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private enum Metric {
    static let horizontalPadding: CGFloat = 20
    static let settingsTopSpacing: CGFloat = 8
    static let settingsButtonSize: CGFloat = 48
    static let titleTopSpacing: CGFloat = 68
    static let titleToPixelMinimumSpacing: CGFloat = 72
    static let pixelWidth: CGFloat = 250
    static let pixelHeight: CGFloat = 175
    static let pixelToButtonMinimumSpacing: CGFloat = 64
    static let progressButtonHeight: CGFloat = 60
    static let bottomSpacing: CGFloat = 20
}

#Preview("여행 진행 중 홈") {
    TabView {
        TripInProgressHomeView()
            .tabItem {
                Label("지도", systemImage: "house.fill")
            }

        Color(.systemBackground)
            .tabItem {
                Label("픽셀맵", systemImage: "mappin.and.ellipse")
            }
    }
    .tint(PicselColor.tripHomeButtonStart)
}
