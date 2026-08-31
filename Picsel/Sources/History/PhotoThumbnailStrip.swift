//
//  PhotoThumbnailStrip.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import SwiftUI

struct PhotoThumbnailStrip: View {

    let photos: [PickedPhoto]
    let canAddMore: Bool
    let onAddTapped: () -> Void
    let onDelete: (PickedPhoto) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // TODO: Step 3 - canAddMore일 때 + 버튼 셀
                if canAddMore {
                    Button(action: onAddTapped) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay {
                                Image(systemName: "plus")
                                    .foregroundStyle(.gray)
                            }
                    }
                }

                // TODO: Step 3 - photos를 썸네일로 (Image(uiImage:) + 삭제 버튼)
                ForEach(photos) { photo in
                    if let uiImage = UIImage(data: photo.imageData) {
                        HStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        onDelete(photo)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .black.opacity(0.5))
                                    }
                                    .padding(4)
                                }
                        }
                        
                    }
                }
            }
        }
    }
}
