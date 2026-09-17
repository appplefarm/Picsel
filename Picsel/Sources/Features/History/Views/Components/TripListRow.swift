//
//  TripListRow.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import SwiftUI

/// 목록에 한 줄로 들어가는 여행 기록입니다.
///
/// 픽셀맵의 최근 기록과 지역 상세의 시트에서 씁니다.
/// 픽셀 히스토리의 큰 카드(TripHistoryCard)와 달리, 한 화면에 여러 개를 쌓는 용도입니다.
struct TripListRow: View {

    let title: String
    let travelDate: Date
    let photoURL: URL?
    /// 목적지 사진을 표시할 수 없을 때 사용할 기존 첨부 사진입니다.
    var fallbackPhotoData: Data? = nil
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        HStack(spacing: 16) {
            thumbnail
                .frame(width: 88, height: 62)
                .clipShape(.rect(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(PicselFont.label02)
                    .foregroundStyle(PicselColor.textPrimary)
                    .lineLimit(1)

                Text(travelDate, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                    .font(PicselFont.caption01)
                    .foregroundStyle(PicselColor.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(height: 78)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PicselColor.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(PicselColor.borderBrandSubtle, lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let photoURL {
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackPhoto
                }
            }
        } else {
            fallbackPhoto
        }
    }

    @ViewBuilder
    private var fallbackPhoto: some View {
        if let data = fallbackPhotoData,
           let image = TripPhotoImage.downsampled(data, maxPixelSize: 88 * displayScale) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            PicselColor.pixelLockedFill
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TripListRow(
            title: "나나와 다녀온 포항항 여행",
            travelDate: .now,
            photoURL: URL(string: "https://picsum.photos/seed/picsel-row/300/200")
        )

        TripListRow(
            title: "사진이 없는 여행",
            travelDate: .now,
            photoURL: nil
        )
    }
    .padding(20)
    .background(PicselColor.backgroundWarmWhite)
}
