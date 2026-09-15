//
//  TripHistoryCard.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import SwiftUI

/// 픽셀 히스토리 목록의 카드 한 장입니다.
///
/// 배경은 그 여행의 최종 목적지 사진(수상작)이고, 아래쪽에 제목과 날짜를 얹습니다.
struct TripHistoryCard: View {

    let title: String
    let travelDate: Date
    let placeCount: Int
    let photoURL: URL?

    var body: some View {
        photo
            .frame(height: 190)
            .frame(maxWidth: .infinity)
            .overlay { shade }
            .overlay(alignment: .bottomLeading) { caption }
            .clipShape(.rect(cornerRadius: 20))
            .accessibilityElement(children: .combine)
    }

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
                    PicselColor.pixelLockedFill
                }
            }
        } else {
            PicselColor.pixelLockedFill
        }
    }

    /// 어떤 사진 위에서도 흰 글씨가 읽히도록 아래쪽을 어둡게 덮습니다.
    private var shade: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.62)],
            startPoint: .center,
            endPoint: .bottom
        )
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(PicselFont.title03)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(subtitle)
                .font(PicselFont.body02)
                .foregroundStyle(PicselColor.textOnBrand)
        }
        .padding(.leading, 18)
        .padding(.trailing, 18)
        .padding(.bottom, 20)
    }

    private var subtitle: String {
        let date = travelDate.formatted(
            .dateTime.year().month(.twoDigits).day(.twoDigits)
        )
        return "\(date) · \(placeCount)개의 장소"
    }
}

#Preview {
    VStack(spacing: 22) {
        TripHistoryCard(
            title: "나나와 다녀온 포항 여행",
            travelDate: .now,
            placeCount: 3,
            photoURL: URL(string: "https://picsum.photos/seed/picsel-history/800/500")
        )

        TripHistoryCard(
            title: "사진이 없는 여행",
            travelDate: .now,
            placeCount: 2,
            photoURL: nil
        )
    }
    .padding(20)
    .background(PicselColor.backgroundWarmWhite)
}
