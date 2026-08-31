//
//  TripRecordView.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import SwiftUI

struct TripRecordView: View {

    @State private var viewModel = TripRecordViewModel()
    @State private var isGalleryPresented = false
    @State private var isPixelUnlockedPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // TODO: Step 1 - 헤더 (타이틀 "오늘 여행의 마무리" + 안내 문구)

            // TODO: Step 1 - TitleTextField(text: $viewModel.title)

            // TODO: Step 1 - MemoTextEditor(text: $viewModel.memo, maxCount: viewModel.maxMemoCount)

            // TODO: Step 3 - PhotoThumbnailStrip(...)  + 버튼 탭 시 isGalleryPresented = true

            Spacer()

            // TODO: Step 5 - 저장 버튼 ("인증하고 픽셀 채우기"), disabled(!viewModel.canSave)
        }
        .padding(20)
        .sheet(isPresented: $isGalleryPresented) {
            // TODO: Step 4 - GalleryPickerView(...)
        }
        .navigationDestination(isPresented: $isPixelUnlockedPresented) {
            // TODO: Step 6 - PixelUnlockedView(...)
        }
    }
}

#Preview {
    NavigationStack {
        TripRecordView()
    }
}

