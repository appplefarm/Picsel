//
//  HomeRootView.swift
//  Picsel
//

import SwiftData
import SwiftUI

/// 저장된 여행 상태에 따라 일반 홈과 활성 여행 홈을 전환합니다.
///
/// `Trip.startTime != nil && !Trip.isDone`인 여행은 앱을 다시 실행해도
/// SwiftData에서 복원됩니다. 경로를 확정한 뒤 아직 시작하지 않은 여행은
/// AppRouter에 저장된 준비중 여행 ID를 기준으로 준비 화면을 복원합니다.
struct HomeRootView: View {
    @Environment(AppRouter.self) private var router
    @Query private var trips: [Trip]
    @State private var sessionTripID: UUID?

    private var latestActiveTrip: Trip? {
        trips
            .filter { $0.startTime != nil && !$0.isDone }
            .max { lhs, rhs in
                (lhs.startTime ?? .distantPast) < (rhs.startTime ?? .distantPast)
            }
    }

    /// 강제 종료 전에 준비중이었던 여행을 다른 활성 여행보다 우선합니다.
    private var persistedReadyTrip: Trip? {
        guard let readyTripID = router.tripReadyTripID else { return nil }
        return trips.first { trip in
            trip.id == readyTripID && !trip.isDone
        }
    }

    /// 기록 저장으로 isDone이 true가 된 직후에도 현재 NavigationStack을 유지합니다.
    /// 픽셀 획득 화면의 버튼이 AppRouter를 초기화하면 새 HomeRootView가 만들어집니다.
    private var displayedTrip: Trip? {
        if let persistedReadyTrip {
            return persistedReadyTrip
        }
        if let sessionTripID,
           let sessionTrip = trips.first(where: { $0.id == sessionTripID }) {
            return sessionTrip
        }
        return latestActiveTrip
    }

    var body: some View {
        Group {
            if let trip = displayedTrip {
                ActiveTripHomeFlow(
                    trip: trip,
                    startsInReadyState: router.tripReadyTripID == trip.id
                )
                    .id(trip.id)
            } else {
                HomeView()
            }
        }
        .task {
            if sessionTripID == nil {
                sessionTripID = persistedReadyTrip?.id ?? latestActiveTrip?.id
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
    private enum HomeMode {
        case ready
        case inProgress
    }

    @Environment(AppRouter.self) private var router
    let trip: Trip

    @State private var homeMode: HomeMode
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

    init(trip: Trip, startsInReadyState: Bool) {
        self.trip = trip
        _homeMode = State(initialValue: startsInReadyState ? .ready : .inProgress)
    }

    var body: some View {
        Group {
            switch homeMode {
            case .ready:
                TripReadyHomeView(
                    cityName: trip.recordRegionName,
                    regionCode: trip.targetPixelCode ?? trip.pixelTile?.code,
                    onSettingsTapped: { isSettingsPresented = true },
                    onStartTripTapped: startTrip
                )
            case .inProgress:
                TripInProgressHomeView(
                    cityName: trip.recordRegionName,
                    regionCode: trip.targetPixelCode ?? trip.pixelTile?.code,
                    onSettingsTapped: { isSettingsPresented = true },
                    onTripProgressTapped: { isTripProgressPresented = true }
                )
            }
        }
        .navigationDestination(isPresented: $isSettingsPresented) {
            SettingsView()
                .toolbar(.hidden, for: .tabBar)
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

    private func startTrip() {
        router.markTripAsStarted(trip.id)
        homeMode = .inProgress
        isTripProgressPresented = true
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
