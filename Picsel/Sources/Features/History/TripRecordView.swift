//
//  TripRecordView.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import SwiftUI
import SwiftData
import PhotosUI

/// 이 화면에서 키보드 포커스를 가질 수 있는 입력 칸.
enum TripRecordField: Hashable {
    case title
    case memo
}

struct TripRecordView: View {

    /// 이 화면에서 기록할 여행입니다. 앞 화면에서 그대로 넘겨받습니다.
    let trip: Trip

    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = TripRecordViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isGalleryPresented = false
    @State private var isPixelUnlockedPresented = false
    @FocusState private var focusedField: TripRecordField?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("오늘 여행의 마무리")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("이번 여행은 어떠셨나요?\n나만의 여행 제목과 내용을 간단히 작성해 픽셀에 보관해보세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TitleTextField(
                    text: $viewModel.title,
                    focusedField: $focusedField
                )
                
                MemoTextEditor(
                    text: $viewModel.memo,
                    focusedField: $focusedField,
                    maxCount: viewModel.maxMemoCount
                )
                
                PhotoThumbnailStrip(
                    photos: viewModel.pickedPhotos,
                    canAddMore: viewModel.canAddMorePhotos,
                    onAddTapped: { isGalleryPresented = true },
                    onDelete: { viewModel.removePhoto($0) }
                )
                
                Text("여행 제목과 내용은 픽셀 상세에 저장돼요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Button {
                    focusedField = nil
                    // 저장이 끝난 뒤에만 결과 화면으로 넘어갑니다.
                    guard viewModel.save(to: trip, in: modelContext) else { return }
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
            .frame(maxWidth: .infinity, alignment: .leading)
            // 입력 칸 바깥을 탭하면 키보드를 내린다.
            // .contentShape가 없으면 VStack의 빈 여백은 탭 판정에 잡히지 않는다.
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            viewModel.prefillTitleIfNeeded(for: trip)
            // 저장할 때 경계 데이터 파싱으로 화면이 끊기지 않도록 미리 읽어 둡니다.
            Task.detached(priority: .utility) { PixelRegionLocator.preload() }
        }
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
                snapshot: viewModel.makeSnapshot(for: trip),
                unlockedRegionCode: trip.targetPixelCode
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { focusedField = nil }
            }
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
        TripRecordView(trip: .previewSample)
    }
    .environment(AppRouter())
    .modelContainer(
        for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self],
        inMemory: true
    )
}
