//
//  PicselMapView.swift
//  Picsel
//
//  Created by JonghyeonLee on 9/1/26.
//

import SwiftUI

struct PicselMapView: View {
    @State private var viewModel: PicselMapViewModel

    private let pixelResolution: Int
    private let onOpenRegion: (AdministrativeRegion) -> Void

    /// `pixelResolution`이 작을수록 경계 픽셀이 더 굵고 도드라집니다.
    init(
        regions: [AdministrativeRegion],
        unlockedRegionCodes: Set<String> = [],
        pixelResolution: Int = 360,
        onOpenRegion: @escaping (AdministrativeRegion) -> Void = { _ in }
    ) {
        _viewModel = State(
            initialValue: PicselMapViewModel(
                regions: regions,
                unlockedRegionCodes: unlockedRegionCodes
            )
        )
        self.pixelResolution = pixelResolution
        self.onOpenRegion = onOpenRegion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ZStack(alignment: .bottom) {
                if viewModel.regions.isEmpty {
                    ContentUnavailableView(
                        "행정구역 경계를 불러오지 못했어요",
                        systemImage: "map"
                    )
                } else {
                    AdministrativeRegionMapView(
                        regions: viewModel.regions,
                        unlockedRegionCodes: viewModel.unlockedRegionCodes,
                        selectedRegionCode: viewModel.selectedRegionCode,
                        pixelResolution: pixelResolution,
                        onSelectRegion: viewModel.selectRegion
                    )
                }

                if let selectedRegion = viewModel.selectedRegion {
                    selectionCard(for: selectedRegion)
                        .padding(16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .navigationTitle("픽셀맵")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedRegionCode)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("여행으로 해금한 지역을 확인해보세요")
                .font(.title2.weight(.semibold))

            Text("지역 타일을 눌러 획득 상태를 확인해보세요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func selectionCard(for region: AdministrativeRegion) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(region.name)
                    .font(.headline)

                Text(viewModel.isSelectedRegionUnlocked ? "해금한 픽셀" : "아직 잠긴 픽셀")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("열기") {
                onOpenRegion(region)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isSelectedRegionUnlocked)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }
}
