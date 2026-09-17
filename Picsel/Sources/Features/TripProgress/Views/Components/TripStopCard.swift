//
//  TripStopCard.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import SwiftUI

/// 여행 진행 화면의 장소 카드입니다.
/// 사진 · 장소명 · 지역 · 길찾기 버튼으로 이루어집니다.
struct TripStopCard: View {

    let name: String
    /// 시안처럼 줄인 지역 표기입니다. (예: "경북 포항시 남구")
    let regionText: String?
    let photoURL: URL?
    let onNavigateTapped: () -> Void
    var tripID: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            photo

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(PicselFont.label01)
                        .foregroundStyle(PicselColor.placeName)
                        .lineLimit(1)

                    if let regionText {
                        HStack(spacing: 3) {
                            // TODO: 시안의 핀 아이콘 SVG를 Assets에 넣고 교체합니다.
                            Image(systemName: "mappin")
                                .font(PicselFont.caption01)

                            Text(regionText)
                                .font(PicselFont.caption01)
                        }
                        .foregroundStyle(PicselColor.locationLabel)
                        .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                navigateButton
            }
            .padding(.horizontal, Metric.footerHorizontalPadding)
            .frame(height: Metric.footerHeight)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Metric.cornerRadius, style: .continuous))
        .shadow(color: PicselColor.cardShadow, radius: 5, x: 0, y: 4)
    }

    private var photo: some View {
        // 사진이 없거나 로딩 중일 때도 카드 높이가 흔들리지 않게 고정 높이를 씁니다.
        RemotePlacePhoto(url: photoURL, tripID: tripID)
            .frame(height: Metric.photoHeight)
            .clipped()
    }

    private var navigateButton: some View {
        Button(action: onNavigateTapped) {
            HStack(spacing: 4) {
                Text("➤")
                    .font(PicselFont.label03)

                Text("길찾기")
                    .font(PicselFont.caption01)
            }
            .foregroundStyle(.white)
            .padding(10)
            .background(PicselColor.actionGreen)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) 길찾기")
    }
}

/// 시안(285 x 215)에서 가져온 값입니다.
private enum Metric {
    static let cornerRadius: CGFloat = 18
    /// 카드 높이의 약 66%가 사진입니다.
    static let photoHeight: CGFloat = 142
    static let footerHeight: CGFloat = 73
    static let footerHorizontalPadding: CGFloat = 22
    static let nameFontSize: CGFloat = 16
    static let regionFontSize: CGFloat = 12
}

#if DEBUG
#Preview("장소 카드") {
    VStack(spacing: 28) {
        TripStopCard(
            name: "호미곶 해맞이광장",
            regionText: "경북 포항시 남구",
            photoURL: URL(string: "https://picsum.photos/seed/homigot/600/400"),
            onNavigateTapped: {}
        )

        TripStopCard(
            name: "구룡포 일본인가옥거리",
            regionText: "경북 포항시 남구",
            photoURL: nil,
            onNavigateTapped: {}
        )
    }
    .padding(.leading, 28)
    .padding(.trailing, 39)
    .background(Color.white)
}
#endif
