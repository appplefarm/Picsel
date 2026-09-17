//
//  PhotoThumbnailStrip.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import SwiftUI

/// 기록에 넣을 사진을 고르고 확인하는 줄입니다.
struct PhotoThumbnailStrip: View {

    let photos: [PickedPhoto]
    let canAddMore: Bool
    let onAddTapped: () -> Void
    let onDelete: (PickedPhoto) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("나의 사진")
                .font(PicselFont.label01)
                .foregroundStyle(PicselColor.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if canAddMore {
                        addButton
                    }

                    ForEach(photos) { photo in
                        thumbnail(for: photo)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 사진 추가

    private var addButton: some View {
        Button(action: onAddTapped) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PicselColor.photoAddBackground)
                .frame(width: 100, height: 100)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(PicselColor.borderBrandSubtle, lineWidth: 1)
                }
                .overlay {
                    Image(systemName: "plus")
                        .font(PicselFont.title03)
                        .foregroundStyle(PicselColor.photoAddIcon)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("사진 추가")
    }

    // MARK: - 사진 한 장

    private func thumbnail(for photo: PickedPhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            photoImage(for: photo)
                .frame(width: 100, height: 100)
                .clipShape(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            deleteButton(for: photo)
                // 썸네일 바깥으로 내밀면 스크롤 영역에 잘리므로 안쪽에 둡니다.
                .padding(2)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func photoImage(for photo: PickedPhoto) -> some View {
        if let uiImage = UIImage(data: photo.imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            // 이미지를 읽지 못해도 자리는 유지해 순서가 흐트러지지 않게 합니다.
            PicselColor.photoAddBackground
        }
    }

    private func deleteButton(for photo: PickedPhoto) -> some View {
        Button {
            onDelete(photo)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(PicselFont.title03)
                .foregroundStyle(.white, .black.opacity(0.45))
                // 아이콘보다 넉넉한 탭 영역을 줍니다.
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("사진 삭제")
    }
}

#Preview("사진 선택") {
    PhotoThumbnailStrip(
        photos: [.previewPhoto(symbol: "mountain.2.fill"), .previewPhoto(symbol: "fork.knife")],
        canAddMore: true,
        onAddTapped: {},
        onDelete: { _ in }
    )
    .padding(20)
    .background(PicselColor.backgroundWarmWhite)
}

#Preview("비어 있음") {
    PhotoThumbnailStrip(
        photos: [],
        canAddMore: true,
        onAddTapped: {},
        onDelete: { _ in }
    )
    .padding(20)
    .background(PicselColor.backgroundWarmWhite)
}


private extension PickedPhoto {
    static func previewPhoto(symbol: String) -> PickedPhoto {
        let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 52))!
        return PickedPhoto(imageData: image.pngData()!)
    }
}
