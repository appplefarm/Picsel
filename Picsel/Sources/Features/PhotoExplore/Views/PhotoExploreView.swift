//
//  PhotoExploreView.swift
//  Picsel
//

import SwiftUI

/// 관광사진 탐색 화면의 상태를 그리는 진입점입니다.
struct PhotoExploreView: View {
    private let onConfirm: (PhotoDestination) -> Void

    @State private var viewModel: PhotoExploreViewModel

    init(
        service: any PhotoDestinationService,
        onConfirm: @escaping (PhotoDestination) -> Void
    ) {
        self.onConfirm = onConfirm
        _viewModel = State(
            initialValue: PhotoExploreViewModel(service: service)
        )
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                ProgressView(
                    "관광사진 \(SpatialPlaceItem.displayLimit)장을 불러오는 중…"
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case let .loaded(destinations):
                SpatialPhotoCanvas(
                    destinations: destinations,
                    onConfirm: onConfirm
                )
                .id(destinations)

            case .empty:
                ContentUnavailableView(
                    "표시할 관광사진이 없어요",
                    systemImage: "photo.on.rectangle.angled"
                )

            case let .failed(message):
                ContentUnavailableView {
                    Label("사진을 불러오지 못했어요", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("다시 시도", action: viewModel.retry)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task(id: viewModel.loadRequest) {
            await viewModel.load()
        }
        .navigationTitle("사진으로 목적지 고르기")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}
