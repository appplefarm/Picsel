//
//  PicselMapView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/1/26.
//

import SwiftUI

struct PicselMapView: View {
    @State private var viewModel: PicselMapViewModel
    @State private var visibleRecordID: UUID?
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("나의 픽셀맵")
                        .font(.system(size: titleSize, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)

                    Text("다녀온 여행으로 대한민국을 채워보세요.")
                        .font(.footnote)
                }

                Spacer()

                historyButton
            }

            map
                .frame(minHeight: 280, maxHeight: .infinity)

            recentPixelSection
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    /// 다녀온 여행을 모아 보는 픽셀 히스토리로 들어갑니다.
    private var historyButton: some View {
        NavigationLink {
            PixelHistoryScreen()
        } label: {
            Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                .font(.system(size: 20, weight: .medium))
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
                    unlockedRegionCodes: unlockedRegionCodes.union(records.map(\.regionCode)),
                    selectedRegionCode: viewModel.selectedRegionCode,
                    pixelResolution: pixelResolution,
                    onSelectRegion: viewModel.selectRegion
                )
            }
        }
    }

    private var recentPixelSection: some View {
        let displayedRecords = viewModel.displayedRecords(in: records)

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(for: displayedRecords)

            if displayedRecords.isEmpty {
                emptyRecordPlaceholder
            } else {
                recordCarousel(displayedRecords)
            }
        }
        // 지역을 바꾸면 첫 카드부터 다시 보여 줍니다.
        // 바뀐 뒤의 목록을 써야 하므로 여기서 다시 구합니다.
        .onChange(of: viewModel.selectedRegionCode) { _, _ in
            visibleRecordID = viewModel.displayedRecords(in: records).first?.id
        }
    }

    private func sectionHeader(for displayedRecords: [PicselMapRecord]) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(viewModel.selectedRegion.map { "\($0.name) 픽셀" } ?? "최근 채운 픽셀")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // 카드가 여러 장일 때만 몇 번째를 보고 있는지 알려 줍니다.
            if displayedRecords.count > 1 {
                Text("\(currentPage(in: displayedRecords)) / \(displayedRecords.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel(
                        "기록 \(displayedRecords.count)개 중 \(currentPage(in: displayedRecords))번째"
                    )
            }
        }
        .padding(.horizontal, 8)
    }

    /// 같은 지역을 여러 번 여행했으면 카드를 옆으로 넘겨 볼 수 있습니다.
    private func recordCarousel(_ displayedRecords: [PicselMapRecord]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(displayedRecords) { record in
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
                    // 카드 한 장이 스크롤 영역을 꽉 채워 한 장씩 넘어가게 합니다.
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $visibleRecordID)
        .scrollDisabled(displayedRecords.count <= 1)
        // ScrollView는 스크롤하지 않는 축으로도 주어진 공간을 전부 차지합니다.
        // 그대로 두면 카드 위아래로 빈 공간이 크게 생기므로 높이를 내용에 맞춥니다.
        .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyRecordPlaceholder: some View {
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

    /// 지금 보이는 카드가 몇 번째인지 셉니다. 아직 정해지지 않았다면 첫 장으로 봅니다.
    private func currentPage(in displayedRecords: [PicselMapRecord]) -> Int {
        let index = displayedRecords.firstIndex { $0.id == visibleRecordID } ?? 0
        return index + 1
    }
}
