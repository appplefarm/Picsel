//
//  PicselMapView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/1/26.
//

import SwiftUI

struct PicselMapView: View {
    @State private var viewModel: PicselMapViewModel
    /// 채워진 픽셀을 누르면 그 지역 상세로 들어갑니다.
    @State private var selectedPixelRegion: AdministrativeRegion?

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
        .navigationDestination(item: $selectedPixelRegion) { region in
            PixelRegionScreen(
                region: region,
                unlockedRegionCodes: allUnlockedRegionCodes
            )
        }
        .task { await viewModel.loadRegions() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("나의 픽셀맵")
                        .font(PicselFont.title02)
                        .accessibilityAddTraits(.isHeader)

                    Text("다녀온 여행으로 대한민국을 채워보세요.")
                        .font(PicselFont.body02)
                }

                Spacer()

                historyButton
            }

            map
                .frame(minHeight: 280, maxHeight: .infinity)
                // 지도는 화면을 최대한 넓게 씁니다. 글자보다 여백을 좁게 둡니다.
                .padding(.horizontal, -8)

            recentPixelSection
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    /// 지도에 채워진 것으로 그려야 할 지역 코드입니다.
    private var allUnlockedRegionCodes: Set<String> {
        unlockedRegionCodes.union(records.map(\.regionCode))
    }

    /// 지도에서 지역을 눌렀을 때입니다.
    ///
    /// 하단의 최근 기록은 유지하고, 채워진 픽셀일 때만 지역 상세로 들어갑니다.
    private func handleRegionTap(_ code: String?) {
        viewModel.selectRegion(code: code)

        guard let code,
              let region = viewModel.regions.first(where: { $0.code == code }),
              region.containsAnyRegion(in: allUnlockedRegionCodes)
        else { return }

        selectedPixelRegion = region
    }

    /// 다녀온 여행을 모아 보는 픽셀 히스토리로 들어갑니다.
    private var historyButton: some View {
        NavigationLink {
            PixelHistoryScreen()
        } label: {
            Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                .font(PicselFont.title03)
                .foregroundStyle(PicselColor.homeText)
                .frame(width: 48, height: 48)
                .background(PicselColor.surface, in: .circle)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
        .accessibilityLabel("픽셀 히스토리")
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
                    unlockedRegionCodes: allUnlockedRegionCodes,
                    selectedRegionCode: viewModel.selectedRegionCode,
                    pixelResolution: pixelResolution,
                    onSelectRegion: handleRegionTap
                )
            }
        }
    }

    private var recentPixelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 채운 픽셀")
                .font(PicselFont.label01)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 8)

            // PicselMapScreen에서 최신순으로 전달한 전체 기록 중 첫 건만 표시합니다.
            if let record = records.first {
                NavigationLink {
                    PixelDetailView(
                        snapshot: record.snapshot,
                        stops: record.stops,
                        trip: record.trip
                    )
                } label: {
                    RecentPixelCard(snapshot: record.snapshot)
                }
                .buttonStyle(.plain)
            } else {
                emptyRecordPlaceholder
            }
        }
    }

    private var emptyRecordPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("아직 채운 픽셀이 없어요")
                .font(PicselFont.label01)
            Text("여행을 기록하면 이곳에 추억이 채워져요.")
                .font(PicselFont.caption01)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
    }
}
