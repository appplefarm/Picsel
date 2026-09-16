//
//  PhotoExploreView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import CoreLocation
import SwiftUI

/// 관광사진 탐색 화면의 상태를 그리는 진입점입니다.
struct PhotoExploreView: View {
    private let onConfirm: (PhotoDestination) -> Void
    private let sourceNotice: String?
    private let originLocation: CLLocation?
    private let directionsService: any RouteDirectionsProviding

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PhotoExploreViewModel
    @State private var isSceneLoading = true
    @State private var isEmptyAlertPresented = false

    init(
        service: any PhotoDestinationService,
        sourceNotice: String? = nil,
        originLocation: CLLocation? = nil,
        directionsService: any RouteDirectionsProviding = NaverDirectionsService(),
        onConfirm: @escaping (PhotoDestination) -> Void
    ) {
        self.onConfirm = onConfirm
        self.sourceNotice = sourceNotice
        self.originLocation = originLocation
        self.directionsService = directionsService
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
        .task(id: viewModel.loadRequest) {
            isSceneLoading = true
            await viewModel.load()
            if case .empty = viewModel.phase {
                isEmptyAlertPresented = true
            }
        }
        .alert(
            "추천할 장소를 찾지 못했어요",
            isPresented: $isEmptyAlertPresented
        ) {
            Button("반경 다시 설정") {
                dismiss()
            }
        } message: {
            Text("선택한 반경 안에서 추천할 장소를 찾지 못했어요.\n반경을 넓혀보세요.")
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(isLoading ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .tint(PicselColor.textPrimary)
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
                sourceNotice: sourceNotice,
                originLocation: originLocation,
                directionsService: directionsService,
                onSceneLoadingChange: { isSceneLoading = $0 },
                onConfirm: onConfirm
            )
            .id(destinations)

        case .empty:
            Color.clear

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
