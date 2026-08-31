//
//  TripRecordView.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import SwiftUI
import PhotosUI

struct TripRecordView: View {

    @State private var viewModel = TripRecordViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isGalleryPresented = false
    @State private var isPixelUnlockedPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // TODO: Step 1 - 헤더 (타이틀 "오늘 여행의 마무리" + 안내 문구)
            Text("오늘 여행의 마무리")
                .font(.title)
                .fontWeight(.bold)
            
            Text("이번 여행은 어떠셨나요?\n나만의 여행 제목과 내용을 간단히 작성해 픽셀에 보관해보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TitleTextField(text: $viewModel.title)
            
            MemoTextEditor(text: $viewModel.memo, maxCount: viewModel.maxMemoCount)

            // TODO: Step 3 - PhotoThumbnailStrip(...)  + 버튼 탭 시 isGalleryPresented = true
            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: viewModel.maxPhotoCount - viewModel.pickedPhotos.count,
                matching: .images
            ) {
                PhotoThumbnailStrip(
                    photos: viewModel.pickedPhotos,
                    canAddMore: viewModel.canAddMorePhotos,
                    onAddTapped: { isGalleryPresented = true },
                    onDelete: { viewModel.removePhoto($0) }
                )
            }

            // 확인용 임시 — Step 3에서 썸네일로 교체
            Text("\(viewModel.pickedPhotos.count) / \(viewModel.maxPhotoCount)장 선택됨")

            Spacer()

            // TODO: Step 5 - 저장 버튼 ("인증하고 픽셀 채우기"), disabled(!viewModel.canSave)
        }
        .padding(20)
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await loadPhotos(from: newItems) }
        }
        .photosPicker(
            isPresented: $isGalleryPresented,
            selection: $pickerItems,
            maxSelectionCount: viewModel.maxPhotoCount - viewModel.pickedPhotos.count,
            matching: .images
        )
        .navigationDestination(isPresented: $isPixelUnlockedPresented) {
            // TODO: Step 6 - PixelUnlockedView(...)
        }
    }
    
    private func loadPhotos(from items: [PhotosPickerItem]) async {
        var newPhotos: [PickedPhoto] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                newPhotos.append(PickedPhoto(imageData: data))
            }
        }
        viewModel.addPhotos(newPhotos)
        pickerItems = []   // 다음 선택을 위해 비우기
    }
}

#Preview {
    NavigationStack {
        TripRecordView()
    }
}

