//
//  HomeRootView.swift
//  Picsel
//

import SwiftData
import SwiftUI

/// 저장된 여행 상태에 따라 일반 홈과 활성 여행 홈을 전환합니다.
///
/// AppRouter가 활성 여행 한 건을 복원하고, 이 뷰는 결과에 맞는 홈만 표시합니다.
struct HomeRootView: View {
    private enum RestorationState {
        case loading
        case finished
        case failed(Error)
    }

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @State private var restorationState = RestorationState.loading

    var body: some View {
        Group {
            if let trip = router.sessionTrip {
                ActiveTripHomeFlow(
                    trip: trip,
                    // 기존 버전에서 준비 상태인데도 startTime을 미리 기록한 데이터는
                    // UserDefaults의 준비 ID를 함께 확인해 호환합니다.
                    startsInReadyState: trip.startTime == nil
                        || router.tripReadyTripID == trip.id
                )
                    .id(trip.id)
            } else {
                switch restorationState {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PicselColor.homeBackground.ignoresSafeArea())
                case .finished:
                    HomeView()
                case .failed(let error):
                    ContentUnavailableView {
                        Label("여행을 복원하지 못했어요", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("다시 시도", action: restoreTrip)
                        if error is AppRouter.RestorationError {
                            Button("홈으로 돌아가기") {
                                // 여행 기록은 삭제하지 않고 이 여행의 자동 복원만 중단합니다.
                                router.finishTripFlow(returningTo: .home)
                            }
                        }
                    }
                }
            }
        }
        .task(id: router.homeStackID) {
            restoreTrip()
        }
    }

    private func restoreTrip() {
        restorationState = .loading
        do {
            try router.restoreTrip(in: modelContext)
            restorationState = .finished
        } catch {
            restorationState = .failed(error)
        }
    }
}

private struct ActiveTripHomeFlow: View {
    private enum HomeMode {
        case ready
        case inProgress
    }

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    let trip: Trip

    @State private var homeMode: HomeMode
    @State private var isSettingsPresented = false
    @State private var isTripProgressPresented = false
    @State private var isVisitedPlacesPresented = false
    @State private var tripStartErrorMessage: String?

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
        .alert(
            "여행 시작 실패",
            isPresented: Binding(
                get: { tripStartErrorMessage != nil },
                set: { if !$0 { tripStartErrorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(tripStartErrorMessage ?? "")
        }
    }

    private func startTrip() {
        if trip.startTime == nil {
            trip.startTime = Date()
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            tripStartErrorMessage = "여행 시작 상태를 저장하지 못했어요. 잠시 후 다시 시도해주세요."
            return
        }

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
