//
//  PixelRegionView.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import SwiftData
import SwiftUI

/// 저장된 기록을 읽고, 화면에는 표시용 값만 전달합니다.
struct PixelRegionScreen: View {

    /// 지도에서 누른 지역입니다. 코드가 묶여 있어(포항시 = 북구 + 남구) 지역 자체를 넘겨받습니다.
    let region: AdministrativeRegion

    /// 지도 배경에 함께 그릴, 이미 채운 지역들입니다.
    let unlockedRegionCodes: Set<String>

    @Query(
        filter: #Predicate<Trip> { $0.isDone },
        sort: \Trip.createdAt,
        order: .reverse
    )
    private var completedTrips: [Trip]

    var body: some View {
        PixelRegionView(
            region: region,
            unlockedRegionCodes: unlockedRegionCodes,
            trips: completedTrips.filter(belongsToRegion)
        )
    }

    /// 이 지역에서 남긴 기록인지 봅니다.
    ///
    /// 픽셀이 연결됐으면 그 코드를, 아직이면 저장해 둔 목적지 픽셀 코드를 씁니다.
    private func belongsToRegion(_ trip: Trip) -> Bool {
        guard let code = trip.pixel.map({ String($0.regionCode) }) ?? trip.targetPixelCode,
              !code.isEmpty else { return false }

        return region.containsAnyRegion(in: [code])
    }
}

/// 지도에서 채워진 픽셀을 눌렀을 때 뜨는 지역 상세입니다.
///
/// 들어오면 그 픽셀이 커지면서 아래에서 기록 목록이 올라옵니다.
struct PixelRegionView: View {

    let region: AdministrativeRegion
    let unlockedRegionCodes: Set<String>
    let trips: [Trip]

    /// 들어온 뒤 픽셀을 확대하고 목록을 올리는 연출에 씁니다.
    @State private var isZoomedIn = false
    @State private var selectedYear: Int?
    @State private var selectedTrip: Trip?

    /// 목록 패널이 차지하는 화면 비율입니다.
    private let panelHeightRatio: CGFloat = 0.56

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                // 목록이 덮는 만큼 지도 영역을 줄여야, 확대된 픽셀이 보이는 부분의 가운데에 옵니다.
                map
                    .padding(.bottom, proxy.size.height * panelHeightRatio)

                panel
                    .frame(height: proxy.size.height * panelHeightRatio)
                    // 아래에서 올라오는 연출입니다.
                    .offset(y: isZoomedIn ? 0 : proxy.size.height * panelHeightRatio)
            }
        }
        .background(PicselColor.backgroundWarmWhite)
        .navigationBarTitleDisplayMode(.inline)
        // 시안에 탭바가 없습니다. 지도를 최대한 넓게 씁니다.
        .toolbar(.hidden, for: .tabBar)
        .toolbar { ToolbarItem(placement: .principal) { header } }
        .navigationDestination(item: $selectedTrip) { trip in
            PixelDetailView(
                snapshot: trip.makeRecordSnapshot(),
                stops: trip.recordStopDisplays,
                trip: trip
            )
        }
        .task {
            selectedYear = availableYears.first

            // 화면이 뜬 뒤에 값을 바꿔야 확대·상승이 눈에 보입니다.
            withAnimation(.easeOut(duration: 0.55)) { isZoomedIn = true }
        }
    }

    // MARK: - 내비게이션 바

    private var header: some View {
        VStack(spacing: 4) {
            Text("픽셀 \(region.name)")
                .font(PicselFont.title03)
                .foregroundStyle(PicselColor.textPrimary)

            if let period {
                Text(period)
                    .font(PicselFont.caption01)
                    .foregroundStyle(PicselColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 지도

    private var map: some View {
        PixelUnlockedMapView(
            highlightedRegionCode: region.code,
            unlockedRegionCodes: unlockedRegionCodes,
            isRevealed: true,
            keepsFocused: isZoomedIn,
            surroundingOpacity: 0.3
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - 기록 목록

    private var panel: some View {
        VStack(spacing: 0) {
            YearFilterChips(
                years: availableYears,
                selection: $selectedYear,
                showsAllOption: false,
                font: PicselFont.subtitle01
            )
            .padding(.top, 20)

            visitCount
                .padding(.horizontal, 20)
                .padding(.top, 16)

            list
        }
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 34,
                topTrailingRadius: 34,
                style: .continuous
            )
            .fill(PicselColor.backgroundWarmWhite)
            .shadow(color: .black.opacity(0.14), radius: 24, y: -4)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var visitCount: some View {
        HStack {
            Spacer()

            Text("\(filteredTrips.count)번 방문")
                .font(PicselFont.body01)
                .foregroundStyle(PicselColor.pixelVisitCount)
        }
    }

    @ViewBuilder
    private var list: some View {
        if filteredTrips.isEmpty {
            ContentUnavailableView(
                "이 해에 남긴 기록이 없어요",
                systemImage: "photo.on.rectangle.angled"
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredTrips) { trip in
                        // 상세 화면 값은 사진 원본을 담고 있어 누른 뒤에 만듭니다.
                        Button {
                            selectedTrip = trip
                        } label: {
                            TripListRow(
                                title: trip.title,
                                travelDate: trip.recordDate,
                                photoURL: trip.representativePhotoURL
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - 값

    /// 기록이 있는 연도만 최신순으로 보여 줍니다.
    private var availableYears: [Int] {
        Set(trips.map(year(of:))).sorted(by: >)
    }

    private var filteredTrips: [Trip] {
        guard let selectedYear else { return trips }
        return trips.filter { year(of: $0) == selectedYear }
    }

    private func year(of trip: Trip) -> Int {
        Calendar.current.component(.year, from: trip.recordDate)
    }

    /// "2026.08.30 – 09.21" 처럼 첫 기록부터 마지막 기록까지의 기간입니다.
    /// 해가 다르면 양쪽에 연도를 다 적습니다.
    private var period: String? {
        let dates = trips.map(\.recordDate).sorted()
        guard let first = dates.first, let last = dates.last else { return nil }

        let full = Date.FormatStyle.dateTime.year().month(.twoDigits).day(.twoDigits)
        guard first != last else { return first.formatted(full) }

        let sameYear = Calendar.current.isDate(first, equalTo: last, toGranularity: .year)
        let lastText = sameYear
            ? last.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
            : last.formatted(full)

        return "\(first.formatted(full)) – \(lastText)"
    }
}

#Preview {
    NavigationStack {
        PixelRegionView(
            region: PixelRegionLocator.allRegions.first { $0.code == "4711" }
                ?? PixelRegionLocator.allRegions[0],
            unlockedRegionCodes: ["11", "50130"],
            trips: [.previewSample]
        )
    }
    .modelContainer(
        for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self],
        inMemory: true
    )
}
