//
//  PicselMapView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/1/26.
//

import SwiftUI

struct PicselMapView: View {
    @State private var viewModel: PicselMapViewModel
    @ScaledMetric(relativeTo: .title2) private var titleSize = 25.0

    private let unlockedRegionCodes: Set<String>
    private let records: [PicselMapRecord]
    private let pixelResolution: Int

    /// 경계 데이터를 생략하면 번들에서 불러옵니다. 프리뷰는 값을 직접 주입할 수 있습니다.
    init(
        regions: [AdministrativeRegion]? = nil,
        unlockedRegionCodes: Set<String> = [],
        records: [PicselMapRecord] = [],
        pixelResolution: Int = 128
    ) {
        _viewModel = State(initialValue: PicselMapViewModel(regions: regions))
        self.unlockedRegionCodes = unlockedRegionCodes
        self.records = records
        self.pixelResolution = pixelResolution
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content

            // 큰 글씨/가로 화면에서도 기록 카드에 접근할 수 있습니다.
            ScrollView {
                content
            }
        }
        .background(Color(.systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadRegions() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("나의 픽셀맵")
                    .font(.system(size: titleSize, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)

                Text("다녀온 여행으로 대한민국을 채워보세요.")
                    .font(.footnote)
            }

            map
                .frame(minHeight: 280, maxHeight: .infinity)

            recentPixelSection
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var map: some View {
        switch viewModel.phase {
        case .idle, .loading:
            ProgressView("픽셀맵을 불러오는 중이에요")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ContentUnavailableView {
                Label("지도를 불러오지 못했어요", systemImage: "map")
            } description: {
                Text(message)
            } actions: {
                Button("다시 시도") {
                    Task { await viewModel.loadRegions() }
                }
            }

        case .loaded:
            if viewModel.regions.isEmpty {
                ContentUnavailableView("표시할 지역이 없어요", systemImage: "map")
            } else {
                AdministrativeRegionMapView(
                    regions: viewModel.regions,
                    unlockedRegionCodes: unlockedRegionCodes.union(records.map(\.regionCode)),
                    selectedRegionCode: viewModel.selectedRegionCode,
                    pixelResolution: pixelResolution,
                    onSelectRegion: viewModel.selectRegion
                )
            }
        }
    }

    private var recentPixelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.selectedRegion.map { "\($0.name) 픽셀" } ?? "최근 채운 픽셀")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 8)
                .accessibilityAddTraits(.isHeader)

            if let record = viewModel.displayedRecord(in: records) {
                NavigationLink {
                    PixelDetailView(snapshot: record.snapshot, stops: record.stops)
                        .toolbar(.visible, for: .navigationBar)
                } label: {
                    RecentPixelCard(snapshot: record.snapshot)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.selectedRegion == nil ? "아직 채운 픽셀이 없어요" : "이 지역의 여행 기록이 없어요")
                        .font(.subheadline.weight(.semibold))
                    Text("여행을 기록하면 이곳에 추억이 채워져요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
            }
        }
    }
}
