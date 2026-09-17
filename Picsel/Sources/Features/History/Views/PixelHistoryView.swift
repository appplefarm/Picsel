//
//  PixelHistoryView.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import SwiftData
import SwiftUI

/// 탭 진입점에서 저장된 기록을 읽고, 화면에는 표시용 값만 전달합니다.
struct PixelHistoryScreen: View {

    @Query(
        filter: #Predicate<Trip> { $0.isDone },
        sort: \Trip.createdAt,
        order: .reverse
    )
    private var completedTrips: [Trip]

    var body: some View {
        PixelHistoryView(trips: completedTrips)
    }
}

/// 다녀온 여행을 최신순으로 모아 보는 화면입니다.
///
/// 목록은 List로 그립니다. 옆으로 밀어 지우는 동작이 iOS 기본으로 붙고,
/// 카드가 많아져도 보이는 만큼만 그리기 때문입니다.
struct PixelHistoryView: View {

    let trips: [Trip]

    @Environment(\.modelContext) private var modelContext

    /// nil이면 "전체"입니다.
    @State private var selectedYear: Int?
    @State private var selectedTrip: Trip?
    @State private var tripPendingDeletion: Trip?

    var body: some View {
        VStack(spacing: 0) {
            yearFilter

            if filteredTrips.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(PicselColor.backgroundWarmWhite)
        .navigationTitle("픽셀 히스토리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $selectedTrip) { trip in
            PixelDetailView(
                snapshot: trip.makeRecordSnapshot(),
                stops: trip.recordStopDisplays,
                trip: trip
            )
        }
        .alert(
            "이 기록을 지울까요?",
            isPresented: .init(
                get: { tripPendingDeletion != nil },
                set: { if !$0 { tripPendingDeletion = nil } }
            ),
            presenting: tripPendingDeletion
        ) { trip in
            Button("삭제", role: .destructive) { delete(trip) }
            Button("취소", role: .cancel) {}
        } message: { _ in
            Text("사진과 경로가 함께 사라집니다.\n이 지역의 마지막 기록이면 픽셀맵에서도 내려가요.")
        }
        // 기록을 지웠는데 선택된 연도에 남은 기록이 없으면 전체로 되돌립니다.
        .onChange(of: availableYears) { _, years in
            if let selectedYear, !years.contains(selectedYear) {
                self.selectedYear = nil
            }
        }
    }

    // MARK: - 연도 필터

    private var yearFilter: some View {
        YearFilterChips(years: availableYears, selection: $selectedYear)
            .padding(.top, 8)
            .padding(.bottom, 14)
    }

    // MARK: - 목록

    private var list: some View {
        List {
            ForEach(filteredTrips) { trip in
                // NavigationLink를 쓰면 목록에 화살표가 붙고 상세를 미리 만들어 둡니다.
                // 사진 원본을 들고 있는 값이라 누른 뒤에 만들어야 합니다.
                Button {
                    selectedTrip = trip
                } label: {
                    TripHistoryCard(
                        title: trip.title,
                        travelDate: trip.recordDate,
                        placeCount: trip.recordedStops.count,
                        photoURL: trip.representativePhotoURL
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 11, leading: 20, bottom: 11, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    deleteButton(for: trip)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private func deleteButton(for trip: Trip) -> some View {
        // 되돌릴 수 없는 삭제라, 끝까지 밀어도 바로 지우지 않고 한 번 더 확인합니다.
        Button(role: .destructive) {
            tripPendingDeletion = trip
        } label: {
            Label("삭제", systemImage: "trash")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("아직 기록이 없어요", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text(
                selectedYear == nil
                    ? "여행을 마치고 기록을 남기면 이곳에 쌓여요."
                    : "\(selectedYear ?? 0)년에 남긴 기록이 없어요."
            )
        }
        .frame(maxHeight: .infinity)
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

    private func delete(_ trip: Trip) {
        tripPendingDeletion = nil
        UserPixelStore.delete(trip, in: modelContext)
    }
}

#Preview {
    NavigationStack {
        PixelHistoryScreen()
    }
    .modelContainer(
        for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self],
        inMemory: true
    )
}
