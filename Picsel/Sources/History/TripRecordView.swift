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
            Text("오늘 여행의 마무리")
                .font(.title)
                .fontWeight(.bold)
            
            Text("이번 여행은 어떠셨나요?\n나만의 여행 제목과 내용을 간단히 작성해 픽셀에 보관해보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TitleTextField(text: $viewModel.title)
            
            MemoTextEditor(text: $viewModel.memo, maxCount: viewModel.maxMemoCount)
            
            PhotoThumbnailStrip(
                photos: viewModel.pickedPhotos,
                canAddMore: viewModel.canAddMorePhotos,
                onAddTapped: { isGalleryPresented = true },
                onDelete: { viewModel.removePhoto($0) }
            )
            
            Spacer()
            
            Text("여행 제목과 내용은 픽셀 상세에 저장돼요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                isPixelUnlockedPresented = true
            } label: {
                Text("인증하고 픽셀 채우기")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(viewModel.canSave ? Color.black : Color.gray.opacity(0.3))
                    )
            }
            .disabled(!viewModel.canSave)
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
            selectionBehavior: .ordered,
            matching: .images
        )
        .navigationDestination(isPresented: $isPixelUnlockedPresented) {
            PixelUnlockedView(
                thumbnailData: viewModel.pickedPhotos.first?.imageData,
                
                // TODO: Trip 연결 후 실제 지역명
                regionName: "영덕",
                travelDate: .now,
                tripTitle: viewModel.title,
                photoCount: viewModel.pickedPhotos.count,
                
                // TODO: Trip 연결 후 실제 간 장소 수
                placeCount: 3
            )
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

