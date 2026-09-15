//
//  PixelDetailHeroView.swift
//  Picsel
//
//  Created by kosoobin on 9/15/26.
//

import SwiftUI

/// 기록 상세 맨 위에 깔리는 목적지 사진입니다.
///
/// 아래로 당기면 사진이 늘어나고, 위로 올리면 사진이 본문보다 천천히 따라 올라갑니다.
/// 스크롤을 올릴수록 흰 시트가 사진을 덮어 사진이 보이는 면적이 줄어듭니다.
struct PixelDetailHeroView: View {

    let photoURL: URL?
    let title: String
    let travelDate: Date
    /// 편집 중에는 제목을 입력 칸에서 고치므로, 사진 위 제목은 숨깁니다.
    var showsCaption: Bool = true

    /// 본문이 1만큼 올라갈 때 사진은 이만큼만 따라 올라갑니다. 0이면 사진이 완전히 멈춥니다.
    private let parallaxRatio: CGFloat = 0.35

    /// 시트의 둥근 모서리 안쪽으로 사진이 비치도록 아래로 더 그려 두는 높이입니다.
    private let bleedBelowSheet: CGFloat = 30

    var body: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .scrollView).minY
            // 아래로 당긴 거리. 그만큼 사진을 위로 늘립니다.
            let stretch = max(0, minY)
            // 위로 올린 거리만큼 사진을 다시 내려 주면 본문보다 천천히 움직입니다.
            let parallax = minY < 0 ? -minY * (1 - parallaxRatio) : 0

            photo
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height + stretch
                )
                .clipped()
                .overlay { shade }
                .overlay(alignment: .bottomLeading) {
                    if showsCaption {
                        titleBlock
                    }
                }
                .offset(y: -stretch + parallax)
        }
        // 시트가 덮는 만큼 아래로 더 그립니다.
        .frame(height: heroHeight + bleedBelowSheet)
    }

    /// 사진이 보이는 높이입니다. 시트는 이 아래에서 시작합니다.
    static let heroHeight: CGFloat = 240
    private var heroHeight: CGFloat { Self.heroHeight }

    @ViewBuilder
    private var photo: some View {
        if let photoURL {
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        PicselColor.pixelLockedFill
    }

    /// 흰 글씨가 어떤 사진 위에서도 읽히도록 위아래를 어둡게 덮습니다.
    ///
    /// 아래쪽은 제목·날짜를 위해, 위쪽은 내비게이션 바의 뒤로·편집 버튼을 위해 깝니다.
    private var shade: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.28), location: 0),
                .init(color: .clear, location: 0.22),
                .init(color: .black.opacity(0.75), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(PicselFont.title02)
                .foregroundStyle(.white)

            Text(travelDate, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                .font(PicselFont.body01)
                .foregroundStyle(PicselColor.textOnPhotoSecondary)
        }
        .padding(.leading, 24)
        .padding(.trailing, 24)
        // 시트에 가려지는 높이까지 더해 실제로 보이는 영역의 아래쪽에 붙입니다.
        .padding(.bottom, bleedBelowSheet + 21)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            PixelDetailHeroView(
                photoURL: URL(string: "https://picsum.photos/seed/picsel-hero/800/900"),
                title: "니야와 바다 여행",
                travelDate: .now
            )

            Color.white
                .frame(height: 600)
                .clipShape(
                    .rect(topLeadingRadius: 30, topTrailingRadius: 30)
                )
                .padding(.top, -30)
        }
    }
    .ignoresSafeArea(edges: .top)
}
