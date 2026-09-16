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
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @State private var sessionTripID: UUID?
    @State private var restoredTrip: Trip?
    @State private var hasCompletedInitialRestore = false

    private var latestActiveTrip: Trip? {
        trips
            .filter { $0.startTime != nil && !$0.isDone }
            .max { lhs, rhs in
                (lhs.startTime ?? .distantPast) < (rhs.startTime ?? .distantPast)
            }
    }

    /// 경로는 저장했지만 아직 "여행 시작하기"를 누르지 않은 최신 여행입니다.
    /// UserDefaults의 보조 ID가 없어도 SwiftData만으로 준비 화면을 복원합니다.
    private var latestReadyTrip: Trip? {
        trips
            .filter { $0.startTime == nil && !$0.isDone }
            .max { $0.createdAt < $1.createdAt }
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
        // 경로 확정 직후에는 @Query보다 Router의 세션 참조가 먼저 준비됩니다.
        if let sessionTrip = router.sessionTrip {
            return sessionTrip
        }
        if let restoredTrip, !restoredTrip.isDone {
            return restoredTrip
        }
        if let persistedReadyTrip {
            return persistedReadyTrip
        }
        if let sessionTripID,
           let sessionTrip = trips.first(where: { $0.id == sessionTripID }) {
            return sessionTrip
        }
        if let latestReadyTrip {
            return latestReadyTrip
        }
        return latestActiveTrip
    }

    var body: some View {
        Group {
            if let trip = displayedTrip {
                ActiveTripHomeFlow(
                    trip: trip,
                    // 기존 버전에서 준비 상태인데도 startTime을 미리 기록한 데이터는
                    // UserDefaults의 준비 ID를 함께 확인해 호환합니다.
                    startsInReadyState: trip.startTime == nil
                        || router.tripReadyTripID == trip.id
                )
                    .id(trip.id)
            } else if !hasCompletedInitialRestore {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PicselColor.homeBackground.ignoresSafeArea())
            } else {
                HomeView()
            }
        }
        .task(id: router.homeStackID) {
            restoreUnfinishedTrip()

            if sessionTripID == nil {
                if let tripID = router.sessionTrip?.id {
                    sessionTripID = tripID
                } else if let tripID = restoredTrip?.id {
                    sessionTripID = tripID
                } else if let tripID = persistedReadyTrip?.id {
                    sessionTripID = tripID
                } else if let tripID = latestReadyTrip?.id {
                    sessionTripID = tripID
                } else if let tripID = latestActiveTrip?.id {
                    sessionTripID = tripID
                }
            }
        }
        .onChange(of: latestReadyTrip?.id) { _, readyTripID in
            if sessionTripID == nil {
                sessionTripID = readyTripID
            }
        }
        .onChange(of: latestActiveTrip?.id) { _, activeTripID in
            if sessionTripID == nil {
                sessionTripID = activeTripID
            }
        }
    }

    /// 앱 시작 직후 `@Query`가 아직 비어 있어도 로컬 SwiftData 저장소에서
    /// 완료되지 않은 여행을 직접 읽어 준비/진행 홈을 먼저 복원합니다.
    private func restoreUnfinishedTrip() {
        defer { hasCompletedInitialRestore = true }

        if let sessionTrip = router.sessionTrip, !sessionTrip.isDone {
            restoredTrip = sessionTrip
            return
        }

        let descriptor = FetchDescriptor<Trip>(
            predicate: #Predicate { !$0.isDone },
            sortBy: [SortDescriptor(\Trip.createdAt, order: .reverse)]
        )

        do {
            let unfinishedTrips = try modelContext.fetch(descriptor)

            if let readyTripID = router.tripReadyTripID,
               let readyTrip = unfinishedTrips.first(where: { $0.id == readyTripID }) {
                restoredTrip = readyTrip
            } else {
                // 준비 ID가 유실되어도 가장 최근의 미완료 여행을 상태값으로 복원합니다.
                restoredTrip = unfinishedTrips.first
            }
        } catch {
            restoredTrip = nil
            print("저장된 여행 상태 복원에 실패했습니다: \(error.localizedDescription)")
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
