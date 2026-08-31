//
//  TripPhotoScroller.swift
//  Picsel
//
//  "그날의 사진" — 인증 사진 가로 스크롤
//

import SwiftUI

struct TripPhotoScroller: View {

    let photoDataList: [Data]

    private let itemSize: CGFloat = 200

    var body: some View {
        if photoDataList.isEmpty {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.12))
                .frame(height: itemSize)
                .overlay {
                    Text("아직 사진이 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Data는 Identifiable이 아니라서 id: \.self 로 구분한다
                    ForEach(photoDataList, id: \.self) { data in
                        if let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: itemSize, height: itemSize)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TripPhotoScroller(photoDataList: [])
        .padding()
}
