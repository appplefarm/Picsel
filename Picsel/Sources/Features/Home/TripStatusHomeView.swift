//
//  TripStatusHomeView.swift
//  Picsel
//

import SwiftUI

/// 여행 준비/진행 중 홈에서 달라지는 표현만 모아 둡니다.
enum TripHomePresentation {
    case ready
    case inProgress

    func title(for cityName: String) -> String {
        switch self {
        case .ready:
            // 받침이 없거나 ㄹ 받침이면 '로', 그 외에는 '으로'를 사용합니다.
            let lastScalar = cityName.precomposedStringWithCanonicalMapping.unicodeScalars.last?.value
            let finalConsonant = lastScalar.flatMap {
                (0xAC00...0xD7A3).contains($0) ? Int(($0 - 0xAC00) % 28) : nil
            }
            let particle = finalConsonant == 0 || finalConsonant == 8 ? "로" : "으로"
            return "\(cityName)\(particle) 떠나볼까요?"
        case .inProgress:
            return "\(cityName) 여행 중"
        }
    }

    var actionTitle: String {
        switch self {
        case .ready: "여행 시작하기"
        case .inProgress: "여행이 진행중이에요"
        }
    }

    var actionHint: String {
        switch self {
        case .ready: "여행 진행 화면을 엽니다"
        case .inProgress: "진행 중인 여행 화면을 엽니다"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .ready: .light
        case .inProgress: .dark
        }
    }

    var pixelSize: CGSize {
        switch self {
        case .ready: CGSize(width: 210, height: 135)
        case .inProgress: CGSize(width: 250, height: 175)
        }
    }

    var pixelDisplayScale: CGFloat {
        2.1
    }

    var pixelGlowColor: Color {
        switch self {
        case .ready: PicselColor.tripReadyPixelGlow.opacity(0.85)
        case .inProgress: PicselColor.tripHomeGlow.opacity(0.85)
        }
    }

    var pixelGlowRadius: CGFloat {
        switch self {
        case .ready: 10
        case .inProgress: 14
        }
    }

    var actionShadowOpacity: Double {
        switch self {
        case .ready: 0
        case .inProgress: 0.25
        }
    }

    var settingsIconColor: Color {
        switch self {
        case .ready: .black
        case .inProgress: .white
        }
    }
}

/// 두 여행 상태 홈이 공유하는 레이아웃입니다.
struct TripStatusHomeView: View {
    let cityName: String
    let regionCode: String?
    let presentation: TripHomePresentation
    let onSettingsTapped: () -> Void
    let onPrimaryActionTapped: () -> Void

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                settingsButton

                titleSection
                    .padding(.top, Metric.titleTopSpacing)

                Spacer(minLength: Metric.titleToPixelMinimumSpacing)

                pixelView

                Spacer(minLength: Metric.pixelToButtonMinimumSpacing)

                primaryButton
                    .padding(.bottom, Metric.bottomSpacing)
            }
            .padding(.horizontal, Metric.horizontalPadding)
        }
        // 홈의 표현만 바꾸고, 다음 화면까지 다크 모드를 강제하지 않습니다.
        .environment(\.colorScheme, presentation.colorScheme)
        .toolbarColorScheme(presentation.colorScheme, for: .navigationBar)
    }

    @ViewBuilder
    private var background: some View {
        switch presentation {
        case .ready:
            TravelPreparingBackground()
        case .inProgress:
            TripInProgressBackground()
        }
    }

    private var settingsButton: some View {
        HStack {
            Spacer()

            HomeSettingsButton(
                foregroundColor: presentation.settingsIconColor,
                action: onSettingsTapped
            )
        }
        .padding(.top, Metric.settingsTopSpacing)
    }

    @ViewBuilder
    private var pixelView: some View {
        if let regionCode {
            HomeHighlightedPixelView(regionCode: regionCode)
                .frame(width: presentation.pixelSize.width, height: presentation.pixelSize.height)
                .scaleEffect(presentation.pixelDisplayScale)
                .shadow(
                    color: presentation.pixelGlowColor,
                    radius: presentation.pixelGlowRadius
                )
                .accessibilityHidden(true)
        } else {
            Image(systemName: "square.grid.3x3.fill")
                .font(PicselFont.title01)
                .foregroundStyle(PicselColor.tripHomeSubtitle.opacity(0.8))
                .frame(width: presentation.pixelSize.width, height: presentation.pixelSize.height)
                .scaleEffect(presentation.pixelDisplayScale)
                .shadow(
                    color: presentation.pixelGlowColor,
                    radius: presentation.pixelGlowRadius
                )
                .accessibilityHidden(true)
        }
    }

    private var titleSection: some View {
        VStack(spacing: 10) {
            Text(presentation.title(for: cityName))
                .font(PicselFont.title01)
                .foregroundStyle(PicselColor.tripHomeTitle)

            Text("이번 여행이 하나의 픽셀로 남아요")
                .font(PicselFont.subtitle01)
                .foregroundStyle(PicselColor.tripHomeSubtitle)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var primaryButton: some View {
        Button(action: onPrimaryActionTapped) {
            HStack(alignment: .center, spacing: 10) {
                Text(presentation.actionTitle)
                    .font(PicselFont.label01)

                Image(systemName: "chevron.right")
                    .font(PicselFont.label03)
            }
            .foregroundStyle(PicselColor.tripHomeTitle)
            .padding(20)
            .frame(width: 362, alignment: .leading)
            .background(
                LinearGradient(
                    stops: [
                        .init(
                            color: Color(red: 0.22, green: 0.70, blue: 0.53),
                            location: 0.60
                        ),
                        .init(
                            color: Color(red: 0.50, green: 0.82, blue: 0.71),
                            location: 1
                        )
                    ],
                    startPoint: UnitPoint(x: 0, y: 0.5),
                    endPoint: UnitPoint(x: 1, y: 0.5)
                )
            )
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
        .accessibilityHint(presentation.actionHint)
    }
}

/// 픽셀 획득 화면이 처음 보여 주는 한 지역의 모양과 색을 Home에서 재사용합니다.
/// 공통 PixelUnlockedMapView는 변경하지 않고, 확대되어도 선만 화면 기준 굵기로 유지합니다.
private struct HomeHighlightedPixelView: View {
    let regionCode: String

    var body: some View {
        GeometryReader { proxy in
            let camera = PixelMapCamera.focused(
                onRegionCode: regionCode,
                in: proxy.size
            ) ?? .whole

            ZStack {
                ForEach(highlightedTiles) { tile in
                    HomePixelShape(geometry: tile.geometry)
                        .fill(
                            PicselColor.actionGreen.opacity(0.45),
                            style: FillStyle(eoFill: true, antialiased: false)
                        )
                        .overlay {
                            AdministrativeBoundaryOutlineShape(geometry: tile.geometry)
                                .stroke(
                                    PicselColor.primaryGreen.opacity(0.9),
                                    style: StrokeStyle(
                                        lineWidth: Metric.pixelStrokeWidth / max(camera.scale, 1),
                                        lineCap: .square,
                                        lineJoin: .miter
                                    )
                                )
                        }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(camera.scale)
            .offset(camera.offset)
        }
        .clipped()
    }

    private var highlightedTiles: [PixelMapTile] {
        PixelMapGeometryCache.tiles.filter { tile in
            tile.region.containsAnyRegion(in: [regionCode])
        }
    }
}

private struct HomePixelShape: Shape {
    let geometry: AdministrativeRegionTileGeometry

    func path(in rect: CGRect) -> Path {
        geometry.fillPath(in: rect)
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
    static let titleTopSpacing: CGFloat = 68
    static let titleToPixelMinimumSpacing: CGFloat = 72
    static let pixelToButtonMinimumSpacing: CGFloat = 64
    static let pixelStrokeWidth: CGFloat = 0.9
    static let bottomSpacing: CGFloat = 20
}
