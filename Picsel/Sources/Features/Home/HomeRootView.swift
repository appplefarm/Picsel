//
//  HomeRootView.swift
//  Picsel
//

import SwiftData
import SwiftUI

/// 저장된 여행 상태에 따라 일반 홈과 진행 중 홈을 전환합니다.
///
/// `Trip.startTime != nil && !Trip.isDone`인 여행은 앱을 다시 실행해도
/// SwiftData에서 복원되므로 진행 중 홈이 다시 표시됩니다.
struct HomeRootView: View {
    @Query private var trips: [Trip]
    @State private var sessionTripID: UUID?

    private var latestActiveTrip: Trip? {
        trips
            .filter { $0.startTime != nil && !$0.isDone }
            .max { lhs, rhs in
                (lhs.startTime ?? .distantPast) < (rhs.startTime ?? .distantPast)
            }
    }

    /// 기록 저장으로 isDone이 true가 된 직후에도 현재 NavigationStack을 유지합니다.
    /// 픽셀 획득 화면의 버튼이 AppRouter를 초기화하면 새 HomeRootView가 만들어집니다.
    private var displayedTrip: Trip? {
        if let sessionTripID,
           let sessionTrip = trips.first(where: { $0.id == sessionTripID }) {
            return sessionTrip
        }
        return latestActiveTrip
    }

    var body: some View {
        Group {
            if let trip = displayedTrip {
                ActiveTripHomeFlow(trip: trip)
                    .id(trip.id)
            } else {
                HomeView()
            }
        }
        .task {
            if sessionTripID == nil {
                sessionTripID = latestActiveTrip?.id
            }
        }
        .onChange(of: latestActiveTrip?.id) { _, activeTripID in
            if sessionTripID == nil {
                sessionTripID = activeTripID
            }
        }
    }
}

private struct ActiveTripHomeFlow: View {
    let trip: Trip

    @State private var isSettingsPresented = false
    @State private var isTripProgressPresented = false
    @State private var isVisitedPlacesPresented = false

    private var thumbnailURLsByStopID: [UUID: URL] {
        Dictionary(
            uniqueKeysWithValues: trip.stops.compactMap { stop in
                guard let value = stop.photoURL,
                      let url = URL(string: value) else { return nil }
                return (stop.id, url)
            }
        )
    }

    var body: some View {
        TripInProgressHomeView(
            cityName: trip.recordRegionName,
            regionCode: trip.targetPixelCode ?? trip.pixelTile?.code,
            onSettingsTapped: { isSettingsPresented = true },
            onTripProgressTapped: { isTripProgressPresented = true }
        )
        .fullScreenCover(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .navigationDestination(isPresented: $isTripProgressPresented) {
            TripProgressView(
                trip: trip,
                thumbnailURLsByStopID: thumbnailURLsByStopID,
                onFinishTrip: { isVisitedPlacesPresented = true }
            )
            .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $isVisitedPlacesPresented) {
            VisitedPlacesConfirmView(
                viewModel: VisitedPlacesConfirmViewModel(
                    trip: trip,
                    thumbnailURLsByStopID: thumbnailURLsByStopID
                )
            )
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

#Preview("일반 홈") {
    NavigationStack {
        HomeRootView()
    }
    .environment(AppRouter())
    .modelContainer(
        for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self],
        inMemory: true
    )
}
