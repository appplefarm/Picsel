//
//  PhotoExploreView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import SwiftUI

/// 관광사진 탐색 화면의 상태를 그리는 진입점입니다.
struct PhotoExploreView: View {
    private let onConfirm: (PhotoDestination) -> Void
    private let sourceNotice: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel: PhotoExploreViewModel
    @State private var isSceneLoading = true

    init(
        service: any PhotoDestinationService,
        sourceNotice: String? = nil,
        onConfirm: @escaping (PhotoDestination) -> Void
    ) {
        self.onConfirm = onConfirm
        self.sourceNotice = sourceNotice
        _viewModel = State(
            initialValue: PhotoExploreViewModel(service: service)
        )
    }

    var body: some View {
        ZStack {
            content
                .allowsHitTesting(!isLoading)
                .accessibilityHidden(isLoading)

            // 목록 조회에서 이미지·텍스처 준비로 넘어가도 같은 로딩 뷰를 유지합니다.
            if isLoading {
                PhotoExploreLoadingView()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isLoading)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let sourceNotice, !isLoading {
                Text(sourceNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.regularMaterial)
            }
        }
        .task(id: viewModel.loadRequest) {
            isSceneLoading = true
            await viewModel.load()
        }
        .navigationTitle("사진으로 목적지 고르기")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(isLoading ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var isLoading: Bool {
        switch viewModel.phase {
        case .loading: true
        case .loaded: isSceneLoading
        case .empty, .failed: false
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            Color.clear

        case let .loaded(destinations):
            SpatialPhotoCanvas(
                destinations: destinations,
                onSceneLoadingChange: { isSceneLoading = $0 },
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
}
