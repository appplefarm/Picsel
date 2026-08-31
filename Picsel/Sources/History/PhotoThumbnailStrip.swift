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

                // TODO: Step 3 - photos를 썸네일로 (Image(uiImage:) + 삭제 버튼)
            }
        }
    }
}
