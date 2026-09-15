//
//  PixelDetailView.swift
//  Picsel
//
//  기록 상세 — 목적지 사진 위로 기록 시트가 덮는 화면.
//  픽셀맵과 픽셀 히스토리 양쪽에서 같은 화면으로 들어옵니다.
//

import PhotosUI
import SwiftData
import SwiftUI

/// 타임라인 한 줄에 필요한 값.
/// SwiftData 없이도 Preview가 돌게 하려고 화면 전용 타입으로 둔다.
struct RouteStopDisplay: Identifiable {
    let id = UUID()
    let name: String
    let travelMinutesToNext: Int?   // 다음 장소까지 이동 시간, 마지막 장소는 nil
}

extension RouteStopDisplay {
    /// TODO: 경로 데이터 연결 전까지 쓰는 목업
    static let mockStops: [RouteStopDisplay] = [
        RouteStopDisplay(name: "영일대해수욕장", travelMinutesToNext: 12),
        RouteStopDisplay(name: "환호공원", travelMinutesToNext: 8),
        RouteStopDisplay(name: "해안로 작은 카페", travelMinutesToNext: nil)
    ]
}

struct PixelDetailView: View {

    /// TODO: 경로 데이터가 생기면 실제 값으로 교체
    var stops: [RouteStopDisplay] = RouteStopDisplay.mockStops

    /// 편집하려면 저장된 원본이 필요합니다.
    /// 목업으로 띄우는 프리뷰에서는 nil이라 편집 버튼이 보이지 않습니다.
    var trip: Trip?

    @Environment(\.modelContext) private var modelContext

    /// 화면에 보이는 값. 편집을 저장하면 여기도 같이 갱신합니다.
    @State private var record: TripRecordSnapshot
    @State private var editor = PixelDetailEditor()
    @State private var isEditing = false
    @State private var viewingPhoto: ViewingPhoto?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isGalleryPresented = false
    @FocusState private var focusedField: TripRecordField?

    init(
        snapshot: TripRecordSnapshot,
        stops: [RouteStopDisplay] = RouteStopDisplay.mockStops,
        trip: Trip? = nil
    ) {
        _record = State(initialValue: snapshot)
        self.stops = stops
        self.trip = trip
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PixelDetailHeroView(
                    photoURL: record.destinationPhotoURL,
                    title: record.title,
                    travelDate: record.travelDate,
                    showsCaption: !isEditing
                )

                sheet
                    // 시트가 사진 위로 올라와 둥근 모서리 안쪽에 사진이 비칩니다.
                    .padding(.top, -30)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        // 사진이 상태 표시줄까지 올라가고, 내비게이션 바는 그 위에 떠 있습니다.
        .ignoresSafeArea(edges: .top)
        .background(sheetBackground)
        .navigationBarTitleDisplayMode(.inline)
        // 탭바가 사진 위에 떠 있으면 기록을 가립니다.
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(isEditing)
        // 사진 위에 얹히는 버튼이라 밝은 색으로 그려야 읽힙니다.
        // tint를 쓰면 본문의 입력 칸·커서까지 흰색이 되므로 바에만 거는 쪽을 씁니다.
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { toolbarContent }
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await loadPhotos(from: newItems) }
        }
        .photosPicker(
            isPresented: $isGalleryPresented,
            selection: $pickerItems,
            maxSelectionCount: editor.maxPhotoCount - editor.pickedPhotos.count,
            selectionBehavior: .ordered,
            matching: .images
        )
        .fullScreenCover(item: $viewingPhoto) { photo in
            TripPhotoViewer(
                photoDataList: record.photoDataList,
                initialIndex: photo.index
            )
        }
    }

    /// 편집 중에는 흰 입력 칸이 배경과 구분되도록 시트를 한 톤 낮춥니다.
    private var sheetBackground: Color {
        isEditing ? PicselColor.backgroundWarmWhite : PicselColor.surface
    }

    // MARK: - 내비게이션 바

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소", action: cancelEditing)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("완료", action: finishEditing)
                    .fontWeight(.semibold)
                    .disabled(!editor.canSave)
            }
        } else if trip != nil {
            ToolbarItem(placement: .topBarTrailing) {
                Button("편집", action: startEditing)
            }
        }
    }

    // MARK: - 기록 시트

    private var sheet: some View {
        VStack(alignment: .leading, spacing: isEditing ? 24 : 32) {
            if isEditing {
                editingFields
            } else if !record.memo.isEmpty {
                Text(record.memo)
                    .font(PicselFont.body01)
                    .foregroundStyle(PicselColor.textSecondary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !stops.isEmpty {
                RouteTimelineView(stops: stops)
            }

            if !isEditing {
                // 사진이 없으면 TripPhotoGrid가 아무것도 그리지 않아 섹션째 사라집니다.
                TripPhotoGrid(photoDataList: record.photoDataList) { index in
                    viewingPhoto = ViewingPhoto(index: index)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            sheetBackground,
            in: .rect(topLeadingRadius: 30, topTrailingRadius: 30)
        )
    }

    @ViewBuilder
    private var editingFields: some View {
        TitleTextField(
            text: $editor.title,
            focusedField: $focusedField
        )

        MemoTextEditor(
            text: $editor.memo,
            focusedField: $focusedField,
            maxCount: editor.maxMemoCount
        )

        PhotoThumbnailStrip(
            photos: editor.pickedPhotos,
            canAddMore: editor.canAddMorePhotos,
            onAddTapped: { isGalleryPresented = true },
            onDelete: { editor.removePhoto($0) }
        )
    }

    // MARK: - 편집

    private func startEditing() {
        guard let trip else { return }

        editor.load(from: trip)
        // 보기 모드와 편집 모드는 레이아웃이 많이 달라, 애니메이션을 걸면
        // 전환 도중 크기가 어중간한 상태로 한 번 그려집니다. 그냥 바꿉니다.
        isEditing = true
    }

    private func cancelEditing() {
        focusedField = nil
        // 고치던 값을 버리고 저장된 값으로 되돌립니다.
        if let trip {
            editor.load(from: trip)
        }
        isEditing = false
    }

    private func finishEditing() {
        guard let trip else { return }

        focusedField = nil
        // 저장에 실패하면 편집 모드를 유지해 입력한 내용이 사라지지 않게 합니다.
        guard editor.save(to: trip, in: modelContext) else { return }

        record = editor.makeSnapshot(basedOn: record)
        isEditing = false
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        var newPhotos: [PickedPhoto] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                newPhotos.append(PickedPhoto(imageData: data))
            }
        }

        editor.addPhotos(newPhotos)
        pickerItems = []   // 다음 선택을 위해 비우기
    }
}

/// 크게 보기를 어느 사진부터 열지 담아 둡니다.
/// fullScreenCover(item:)에 넘기려면 Identifiable이어야 해서 감쌉니다.
private struct ViewingPhoto: Identifiable {
    let index: Int
    var id: Int { index }
}

#Preview("사진 7장") {
    // 숫자만 바꿔 가며 0~10장 배치를 확인하세요.
    NavigationStack {
        PixelDetailView(snapshot: TripRecordPreviewData.snapshot(photoCount: 7))
    }
}

#Preview("편집 가능") {
    NavigationStack {
        PixelDetailView(
            snapshot: TripRecordPreviewData.snapshot(photoCount: 3),
            trip: .previewSample
        )
    }
    .modelContainer(
        for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self],
        inMemory: true
    )
}
