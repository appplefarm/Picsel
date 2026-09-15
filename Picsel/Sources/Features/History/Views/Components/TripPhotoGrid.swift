//
//  TripPhotoGrid.swift
//  Picsel
//
//  Created by kosoobin on 9/15/26.
//

import SwiftUI
import UIKit

/// 기록 상세 맨 아래의 사진 묶음입니다.
///
/// 사진은 0~10장까지 들어오고 비율도 제각각이라 고정 배치를 쓸 수 없습니다.
/// - 0장: 아무것도 그리지 않습니다. (섹션째 사라집니다)
/// - 1장: 가로를 꽉 채웁니다.
/// - 2장 이상: 두 열에 나눠 담되, 그때그때 더 짧은 열에 넣어 아래쪽 높이를 맞춥니다.
struct TripPhotoGrid: View {

    private let items: [TripPhotoItem]

    private let spacing: CGFloat = 12
    private let cornerRadius: CGFloat = 10

    init(photoDataList: [Data]) {
        items = photoDataList.map(TripPhotoItem.init)
    }

    var body: some View {
        switch items.count {
        case 0:
            EmptyView()

        case 1:
            photo(items[0], maxPixelSize: 1_200)

        default:
            let columns = Self.split(items)

            HStack(alignment: .top, spacing: spacing) {
                column(columns.leading)
                column(columns.trailing)
            }
        }
    }

    private func column(_ items: [TripPhotoItem]) -> some View {
        VStack(spacing: spacing) {
            ForEach(items) { item in
                photo(item, maxPixelSize: 700)
            }
        }
        // 두 열의 너비를 똑같이 나눠 가집니다.
        .frame(width: 180, alignment: .top)
    }

    private func photo(_ item: TripPhotoItem, maxPixelSize: CGFloat) -> some View {
        TripPhotoThumbnail(item: item, maxPixelSize: maxPixelSize)
            // 열 너비가 정해지면 높이는 비율을 따라 정해집니다.
            .aspectRatio(item.displayAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: cornerRadius))
    }

    /// 사진을 두 열에 번갈아 담습니다.
    ///
    /// 열 너비가 같으므로 사진 높이는 가로세로비의 역수에 비례합니다.
    /// 지금까지 쌓인 높이가 더 낮은 열에 다음 사진을 넣으면 두 열의 끝이 비슷하게 맞습니다.
    private static func split(
        _ items: [TripPhotoItem]
    ) -> (leading: [TripPhotoItem], trailing: [TripPhotoItem]) {
        var leading: [TripPhotoItem] = []
        var trailing: [TripPhotoItem] = []
        var leadingHeight: CGFloat = 0
        var trailingHeight: CGFloat = 0

        for item in items {
            let height = 1 / item.displayAspectRatio

            if leadingHeight <= trailingHeight {
                leading.append(item)
                leadingHeight += height
            } else {
                trailing.append(item)
                trailingHeight += height
            }
        }

        return (leading, trailing)
    }
}

// MARK: - 사진 한 장

/// 원본 데이터와 미리 재 둔 가로세로비를 함께 들고 다닙니다.
private struct TripPhotoItem: Identifiable {

    let id = UUID()
    let data: Data
    /// 헤더만 읽어서 잰 원본 비율. 못 읽으면 정사각으로 봅니다.
    let aspectRatio: CGFloat

    init(data: Data) {
        self.data = data
        aspectRatio = TripPhotoImage.aspectRatio(of: data) ?? 1
    }

    /// 화면에 쓸 비율입니다.
    ///
    /// 파노라마나 아주 긴 세로 사진이 화면을 통째로 차지하지 않도록 범위를 묶어 둡니다.
    /// 범위를 벗어난 사진은 잘려서 보입니다.
    var displayAspectRatio: CGFloat {
        min(max(aspectRatio, 0.6), 1.6)
    }
}

/// 사진 한 장을 필요한 크기만큼만 줄여서 펼칩니다.
///
/// 펼치는 일은 화면을 그리는 흐름 밖(`Task.detached`)에서 합니다.
/// 여기서 하면 사진이 여러 장일 때 스크롤이 눈에 띄게 끊깁니다.
private struct TripPhotoThumbnail: View {

    let item: TripPhotoItem
    let maxPixelSize: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                PicselColor.pixelLockedFill
            }
        }
        .task(id: item.id) {
            guard image == nil else { return }

            let data = item.data
            let maxPixelSize = maxPixelSize
            image = await Task.detached(priority: .userInitiated) {
                TripPhotoImage.downsampled(data, maxPixelSize: maxPixelSize)
            }.value
        }
        .accessibilityHidden(true)
    }
}

#Preview("여러 장") {
    // 숫자만 바꿔 가며 1~10장 배치를 확인하세요.
    ScrollView {
        TripPhotoGrid(photoDataList: TripRecordPreviewData.photoDataList(count: 7))
            .padding(24)
    }
}

#Preview("한 장") {
    TripPhotoGrid(photoDataList: TripRecordPreviewData.photoDataList(count: 1))
        .padding(24)
}
