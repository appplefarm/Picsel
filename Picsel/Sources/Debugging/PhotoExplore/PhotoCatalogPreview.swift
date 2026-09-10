//
//  PhotoCatalogPreview.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/10/26.
//

import SwiftUI

#if DEBUG
/// 출시 카탈로그 19개와 미검증 1개를 합쳐 상세 화면의 확정 차단을 확인합니다.
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
                            Text(photo.placeName).font(.headline)
                            Text("\(photo.photoID) · \(photo.photoTitle)")
                            Text(photo.address ?? "주소 없음")
                            Text(photo.locationConfirmed ? "위치 확인됨" : "위치 미검증 · 확정 차단 테스트")
                                .foregroundStyle(photo.locationConfirmed ? Color.secondary : .orange)
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("포항 응답 \(photos.count)개")
            .task {
                do {
                    photos = try await DebugPhotoCatalogClient(scenario: .validation, delay: .zero)
                        .fetchCatalog().photos
                }
                catch { errorMessage = error.localizedDescription }
            }
            .sheet(item: $selectedPhoto) { photo in
                DestinationDetailView(destination: photo, info: DestinationDetailInfo(destination: photo)) {
                    selectedPhoto = nil
                }
            }
        }
    }
}

#Preview("포항 · 미검증 포함 응답 20개") {
    PhotoCatalogPreview()
}

#Preview("포항 · 출시 카탈로그 탐색") {
    NavigationStack {
        PhotoExploreView(
            service: CatalogPhotoDestinationService(client: BundledPhotoCatalogClient()),
            sourceNotice: PhotoDestinationServiceFactory.sourceNotice
        ) { _ in }
    }
}
#endif
