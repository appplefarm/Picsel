//
//  PhotoCatalogPreview.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/10/26.
//

import SwiftUI

#if DEBUG
/// 10장 공간 배치와 별개로, 서버 역할의 20개 원본 응답을 확인하는 Preview입니다.
private struct PhotoCatalogPreview: View {
    @State private var photos: [PhotoCatalogPhoto] = []
    @State private var errorMessage: String?
    @State private var selectedPhoto: PhotoDestination?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage { Text(errorMessage) }
                ForEach(photos, id: \.id) { photo in
                    Button {
                        selectedPhoto = photo.destination
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(photo.placeName).font(PicselFont.label01)
                            Text("\(photo.photoID) · \(photo.photoTitle)")
                            Text(photo.address ?? "주소 없음")
                            Text(photo.locationConfirmed ? "위치 확인됨" : "위치 미검증 · 확정 차단 테스트")
                                .foregroundStyle(photo.locationConfirmed ? Color.secondary : .orange)
                        }
                        .font(PicselFont.caption01)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("포항 응답 \(photos.count)개")
            .task {
                do { photos = try await BundledPhotoCatalogClient().fetchCatalog().photos }
                catch { errorMessage = error.localizedDescription }
            }
            .sheet(item: $selectedPhoto) { photo in
                DestinationDetailView(destination: photo) {
                    selectedPhoto = nil
                }
            }
        }
    }
}

#Preview("포항 목업 · 원본 응답 20개") {
    PhotoCatalogPreview()
}

#Preview("포항 목업 · 사진 탐색") {
    NavigationStack {
        PhotoExploreView(
            service: CatalogPhotoDestinationService(client: BundledPhotoCatalogClient()),
            sourceNotice: "포항 목업 · 위치·반경 필터 미적용"
        ) { _ in }
    }
}
#endif
