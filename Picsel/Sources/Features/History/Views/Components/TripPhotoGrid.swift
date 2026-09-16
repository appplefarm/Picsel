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
/// 사진은 0~10장까지 들어오고 원본 비율도 제각각입니다.
/// 칸 크기를 원본 비율에 맡기면 파노라마 한 장이 화면을 다 먹으므로,
/// 칸은 가로 사진이면 4:3, 세로 사진이면 3:4로 **잘라서** 보여 줍니다.
/// 잘리지 않은 원본은 사진을 눌러 크게 보기에서 확인합니다.
///
/// - 0장: 아무것도 그리지 않습니다. (섹션째 사라집니다)
/// - 1장: 가로를 꽉 채웁니다.
/// - 2장 이상: 두 열에 나눠 담되, 그때그때 더 짧은 열에 넣어 아래쪽 높이를 맞춥니다.
struct TripPhotoGrid: View {

    private let items: [TripPhotoItem]

    /// 사진을 눌렀을 때 몇 번째 사진인지 알려 줍니다.
    private let onSelect: (Int) -> Void

    private let spacing: CGFloat = 12
    private let cornerRadius: CGFloat = 10

    /// 칸 크기를 계산하려고 실제로 쓸 수 있는 가로 폭을 재 둡니다.
    ///
    /// 비율 모디파이어만으로 칸을 잡으면, VStack이 높이를 nil로 제안할 때
    /// SwiftUI가 이미지의 "이상적 크기"(= 원본 픽셀 크기)를 써 버려서 칸이 화면 밖으로 나갑니다.
    /// 그래서 너비를 직접 재고 칸 크기를 숫자로 못 박습니다.
    @State private var availableWidth: CGFloat = 0

    init(photoDataList: [Data], onSelect: @escaping (Int) -> Void = { _ in }) {
        items = photoDataList.enumerated().map(TripPhotoItem.init)
        self.onSelect = onSelect
    }

    var body: some View {
        if items.isEmpty {
            // 빈 자리도 차지하지 않아야 위 칸과의 간격이 생기지 않습니다.
            EmptyView()
        } else {
            VStack(spacing: 0) {
                widthReader
                grid
            }
        }
    }

    /// 높이 0짜리 투명한 자입니다. 레이아웃에는 영향을 주지 않고 폭만 알려 줍니다.
    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { availableWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { _, newValue in
                    availableWidth = newValue
                }
        }
        .frame(height: 0)
    }

    @ViewBuilder
    private var grid: some View {
        if availableWidth > 0 {
            if items.count == 1 {
                tile(items[0], width: availableWidth, maxPixelSize: 1_400)
            } else {
                let columnWidth = ((availableWidth - spacing) / 2).rounded(.down)
                let columns = Self.split(items)

                HStack(alignment: .top, spacing: spacing) {
                    column(columns.leading, width: columnWidth)
                    column(columns.trailing, width: columnWidth)
                }
            }
        } else {
            // 폭을 재기 전 한 프레임 동안만 자리를 비워 둡니다.
            Color.clear.frame(height: 1)
        }
    }

    private func column(_ items: [TripPhotoItem], width: CGFloat) -> some View {
        VStack(spacing: spacing) {
            ForEach(items) { item in
                tile(item, width: width, maxPixelSize: 700)
            }
        }
        .frame(width: width, alignment: .top)
    }

    private func tile(
        _ item: TripPhotoItem,
        width: CGFloat,
        maxPixelSize: CGFloat
    ) -> some View {
        // 칸 높이를 비율에서 직접 구합니다. 제안된 크기에 기대지 않습니다.
        let height = (width / item.tileAspectRatio).rounded()

        return Button {
            onSelect(item.index)
        } label: {
            TripPhotoThumbnail(item: item, maxPixelSize: maxPixelSize)
                .frame(width: width, height: height)
                .clipShape(.rect(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.index + 1)번째 사진 크게 보기")
    }

    /// 사진을 두 열에 번갈아 담습니다.
    ///
    /// 열 너비가 같으므로 칸 높이는 칸 비율의 역수에 비례합니다.
    /// 지금까지 쌓인 높이가 더 낮은 열에 다음 사진을 넣으면 두 열의 끝이 비슷하게 맞습니다.
    private static func split(
        _ items: [TripPhotoItem]
    ) -> (leading: [TripPhotoItem], trailing: [TripPhotoItem]) {
        var leading: [TripPhotoItem] = []
        var trailing: [TripPhotoItem] = []
        var leadingHeight: CGFloat = 0
        var trailingHeight: CGFloat = 0

        for item in items {
            let height = 1 / item.tileAspectRatio

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

/// 원본 데이터와 미리 재 둔 방향을 함께 들고 다닙니다.
private struct TripPhotoItem: Identifiable {

    /// 원본 배열에서 몇 번째인지. 크게 보기를 이 번호로 엽니다.
    let index: Int
    let data: Data
    /// 가로가 더 긴 사진인지. 헤더만 읽어서 판단합니다.
    let isLandscape: Bool

    /// 화면을 다시 그릴 때마다 바뀌지 않아야 사진을 다시 펼치지 않습니다.
    /// 자리(index)가 같아도 다른 사진으로 바뀌었으면 구분되도록 크기를 함께 씁니다.
    var id: String { "\(index)-\(data.count)" }

    init(index: Int, data: Data) {
        self.index = index
        self.data = data
        isLandscape = (TripPhotoImage.aspectRatio(of: data) ?? 1) >= 1
    }

    /// 칸 비율. 가로 사진은 4:3, 세로 사진은 3:4로 잘라 넣습니다.
    var tileAspectRatio: CGFloat {
        isLandscape ? 4.0 / 3.0 : 3.0 / 4.0
    }
}

/// 사진 한 장을 필요한 크기만큼만 줄여서 펼칩니다.
///
/// 펼치는 일은 화면을 그리는 흐름 밖(`Task.detached`)에서 합니다.
/// 여기서 하면 사진이 여러 장일 때 스크롤이 눈에 띄게 끊깁니다.
///
/// 바깥에서 `.frame(width:height:)`으로 칸 크기를 정해 주면,
/// 사진은 그 칸을 꽉 채우고 넘치는 부분은 바깥의 `clipShape`가 잘라 냅니다.
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
            let data = item.data
            let maxPixelSize = maxPixelSize

            image = await Task.detached(priority: .userInitiated) {
                TripPhotoImage.downsampled(data, maxPixelSize: maxPixelSize)
            }.value
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("여러 장") {
    // 숫자만 바꿔 가며 1~10장 배치를 확인하세요.
    ScrollView {
        TripPhotoGrid(photoDataList: TripRecordPreviewData.photoDataList(count: 7))
            .padding(24)
    }
}

#Preview("한 장") {
    ScrollView {
        TripPhotoGrid(photoDataList: TripRecordPreviewData.photoDataList(count: 1))
            .padding(24)
    }
}
#endif
