//
//  TripPhotoViewer.swift
//  Picsel
//
//  Created by kosoobin on 9/15/26.
//

import SwiftUI
import UIKit

/// 사진을 원본 비율 그대로 크게 보는 화면입니다.
///
/// 목록에서는 칸 크기에 맞춰 잘라서 보여 주므로, 사진 전체는 여기서 확인합니다.
/// 여러 장이면 좌우로 넘길 수 있습니다.
struct TripPhotoViewer: View {

    let photoDataList: [Data]

    @State private var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(photoDataList: [Data], initialIndex: Int) {
        self.photoDataList = photoDataList
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedIndex) {
                ForEach(Array(photoDataList.enumerated()), id: \.offset) { index, data in
                    TripPhotoFullImage(data: data)
                        .tag(index)
                }
            }
            .tabViewStyle(
                .page(indexDisplayMode: photoDataList.count > 1 ? .always : .never)
            )
            // 어두운 배경 위에서도 점이 보이도록 받침을 깔아 둡니다.
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    // 아이콘보다 넉넉한 탭 영역을 줍니다.
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .padding(.trailing, 8)
            .accessibilityLabel("닫기")
        }
        // 뒤의 기록 상세가 살짝 비쳐 보이게 둡니다.
        .presentationBackground(.black.opacity(0.92))
    }
}

/// 사진 한 장을 원본 비율 그대로 펼칩니다.
private struct TripPhotoFullImage: View {

    let data: Data

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard image == nil else { return }

            let data = data
            image = await Task.detached(priority: .userInitiated) {
                // 화면 전체에 띄우므로 목록 썸네일보다 크게 펼칩니다.
                TripPhotoImage.downsampled(data, maxPixelSize: 2_000)
            }.value
        }
    }
}

#if DEBUG
#Preview {
    Color.gray
        .ignoresSafeArea()
        .fullScreenCover(isPresented: .constant(true)) {
            TripPhotoViewer(
                photoDataList: TripRecordPreviewData.photoDataList(count: 4),
                initialIndex: 1
            )
        }
}
#endif
