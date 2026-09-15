//
//  DestinationDetailView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import CoreGraphics
import CoreLocation
import Foundation
import SwiftUI

/// 선택된 사진을 최종 목적지로 확정하기 전 보여주는 전체 화면 상세입니다.
struct DestinationDetailView: View {
    let destination: PhotoDestination
    let originLocation: CLLocation?
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var loadedPhoto: CGImage?
    @State private var didFailToLoadPhoto = false
    @State private var viewModel: DestinationDetailViewModel

    init(
        destination: PhotoDestination,
        originLocation: CLLocation? = nil,
        directionsService: any RouteDirectionsProviding = NaverDirectionsService(),
        onConfirm: @escaping () -> Void
    ) {
        self.destination = destination
        self.originLocation = originLocation
        self.onConfirm = onConfirm
        _viewModel = State(initialValue: DestinationDetailViewModel(
            destination: destination,
            directionsService: directionsService
        ))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        destinationPhoto(
                            maxWidth: min(geometry.size.width - 66, 420),
                            maxHeight: min(310, geometry.size.height * 0.48)
                        )

                        if let locationName = destination.address, !locationName.isEmpty {
                            Text(locationName)
                                .font(PicselFont.body01)
                                .multilineTextAlignment(.center)
                                .padding(.top, 16)
                        }

                        travelInformation
                            .padding(.top, 56)

                        Text("이 사진을 목적지로 선택하면 다음 단계에서 출발지와 목적지 사이에서 들를 장소를 추천해드려요")
                            .font(PicselFont.caption01)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 32)

                        if !destination.canSelectAsDestination {
                            Text("위치 정보가 없거나 검증되지 않았어요. 사진은 볼 수 있지만 경로에는 추가할 수 없어요.")
                                .font(PicselFont.caption01)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 16)
                        }
                    }
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 33)
                    .padding(.top, min(80, geometry.size.height * 0.12))
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                confirmButton
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            .background {
                // 직전 RealityKit 공간은 부모에서 흐리게 유지하고 이 화면에서는 딤만 더합니다.
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("사진 탐색으로 돌아가기", systemImage: "chevron.left", action: dismiss.callAsFunction)
                        .labelStyle(.iconOnly)
                }
            }
            .tint(PicselColor.textPrimary)
        }
        .presentationBackground(.clear)
        .task(id: destination.photoURL) {
            await loadPhoto()
        }
        .task(id: TravelRequestID(origin: originLocation, retryAttempt: viewModel.retryAttempt)) {
            await viewModel.loadTravelInfo(from: originLocation)
        }
    }

    private var confirmButton: some View {
        Button("최종 목적지로 선택하기") {
            guard destination.canSelectAsDestination else { return }
            dismiss()
            onConfirm()
        }
        .font(PicselFont.label01)
        .buttonStyle(.primaryGradient)
        .disabled(!destination.canSelectAsDestination)
        .opacity(destination.canSelectAsDestination ? 1 : 0.45)
    }

    @ViewBuilder
    private func destinationPhoto(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        if let loadedPhoto {
            let size = fittedSize(
                for: loadedPhoto,
                maxWidth: maxWidth,
                maxHeight: maxHeight
            )

            Image(loadedPhoto, scale: 1, label: Text(destination.name))
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .background(Color(.systemBackground))
                .clipShape(.rect(cornerRadius: 1))
        } else if didFailToLoadPhoto {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(width: maxWidth, height: maxHeight)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 1))
                .accessibilityLabel("사진을 불러오지 못했습니다")
        } else {
            ProgressView()
                .frame(width: maxWidth, height: maxHeight)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 1))
                .accessibilityLabel("사진 불러오는 중")
        }
    }

    private func fittedSize(
        for image: CGImage,
        maxWidth: CGFloat,
        maxHeight: CGFloat
    ) -> CGSize {
        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height)

        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    private func loadPhoto() async {
        loadedPhoto = nil
        didFailToLoadPhoto = false

        guard let photoURL = destination.photoURL,
              let imageURL = URL(string: photoURL) else {
            didFailToLoadPhoto = true
            return
        }

        do {
            let image = try await RemotePhotoImageLoader.image(
                from: imageURL,
                maximumPixelSize: 2_400
            )
            try Task.checkCancellation()
            loadedPhoto = image
        } catch is CancellationError {
            return
        } catch {
            didFailToLoadPhoto = true
        }
    }

    @ViewBuilder
    private var travelInformation: some View {
        switch viewModel.travelState {
        case .loading:
            ProgressView("거리·시간을 확인하고 있어요")
                .font(PicselFont.caption01)
                .tint(.white)

        case let .loaded(info):
            VStack(spacing: 8) {
                travelChips(info.chips)
                Text("자동차 기준 · 교통 상황에 따라 달라질 수 있어요")
                    .font(PicselFont.caption01)
                    .multilineTextAlignment(.center)
            }

        case let .unavailable(message):
            Text(message)
                .font(PicselFont.caption01)
                .multilineTextAlignment(.center)

        case .failed:
            VStack(spacing: 8) {
                Text("거리·시간을 불러오지 못했어요.")
                    .font(PicselFont.caption01)
                Button("다시 시도", action: viewModel.retry)
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
        }
    }

    private func travelChips(_ chips: [String]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { chipLabels(chips) }
            VStack(spacing: 8) { chipLabels(chips) }
        }
    }

    private func chipLabels(_ chips: [String]) -> some View {
        ForEach(chips, id: \.self) { chip in
            Text(chip)
                .font(PicselFont.caption01)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minWidth: 112, minHeight: 30)
                .background(.white.opacity(0.65), in: .capsule)
        }
    }

    private struct TravelRequestID: Equatable {
        let origin: CLLocation?
        let retryAttempt: Int
    }
}
