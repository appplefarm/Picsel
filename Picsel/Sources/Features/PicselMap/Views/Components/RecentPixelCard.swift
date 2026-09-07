//
//  RecentPixelCard.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/8/26.
//

import SwiftUI

struct RecentPixelCard: View {
    let snapshot: TripRecordSnapshot

    var body: some View {
        HStack(spacing: 18) {
            thumbnail
                .frame(width: 64, height: 60)
                .clipShape(.rect(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text("\(snapshot.travelDate, format: .dateTime.year().month(.twoDigits).day(.twoDigits)) · 사진 \(snapshot.photoCount)장")
                    .font(.caption)

                Text("픽셀 상세 보기 →")
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.primary)
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
        .contentShape(.rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = snapshot.representativePhotoData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color(.systemGray4)
        }
    }
}
