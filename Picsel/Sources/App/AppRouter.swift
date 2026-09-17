//
//  AppRouter.swift
//  Picsel
//
//  Created by kosoobin on 9/11/26.
//

import Foundation
import SwiftData

/// 탭 선택과 여행 흐름의 종료를 한곳에서 관리합니다.
///
/// 여행 기록을 마치고 "홈으로" / "픽셀맵 확인하기"를 누르면
/// 홈에서 쌓아 올린 화면(목적지 고르기 → 경유지 선택 → 경로 확인 → 여행 진행 → 기록 → 픽셀 획득)을
/// 전부 닫고 원하는 탭의 첫 화면으로 돌아가야 합니다.
/// 그 신호를 화면마다 클로저로 넘기는 대신 이 객체 하나로 전달합니다.
@Observable
final class AppRouter {

    private static let tripReadyTripIDKey = "picsel.tripReadyTripID"
    private static let activeTripIDKey = "picsel.activeTripID"

    @ObservationIgnored private let defaults: UserDefaults

    enum Tab: Hashable {
        case home
        case picselMap
    }

    var selectedTab: Tab = .home

    /// 홈 탭 NavigationStack의 정체성입니다.
    ///
    /// 홈에서 이어지는 화면들은 NavigationLink와 navigationDestination이 섞여 있어
    /// 바깥에서 특정 화면만 골라 닫기 어렵습니다.
    /// 이 값을 바꾸면 스택이 통째로 다시 만들어져 첫 화면으로 확실하게 돌아갑니다.
    ///
    /// TODO: 홈 탭 전체를 NavigationStack(path:) 기반으로 바꾸면
    ///       스택을 새로 만들지 않고 경로만 비울 수 있습니다. (별도 이슈)
    private(set) var homeStackID = UUID()

    /// 구버전이 startTime을 미리 저장한 준비 여행을 구분하는 호환용 ID입니다.
    private(set) var tripReadyTripID: UUID?

    /// 준비·진행 상태에 관계없이 재실행 후 이어갈 여행의 ID입니다.
    private(set) var activeTripID: UUID?

    /// 완료 저장 후에도 픽셀 획득 화면이 닫히지 않도록 흐름 종료까지 유지합니다.
    private(set) var sessionTrip: Trip?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        tripReadyTripID = defaults
            .string(forKey: Self.tripReadyTripIDKey)
            .flatMap(UUID.init(uuidString:))
        activeTripID = defaults
            .string(forKey: Self.activeTripIDKey)
            .flatMap(UUID.init(uuidString:))
    }

    /// 홈 진입 시 한 번만 조회합니다. 화면 재계산에서는 sessionTrip을 재사용합니다.
    func restoreTrip(in context: ModelContext) throws {
        guard sessionTrip == nil else { return }

        let tripID = activeTripID ?? tripReadyTripID
        var descriptor: FetchDescriptor<Trip>

        if let tripID {
            descriptor = FetchDescriptor(predicate: #Predicate { $0.id == tripID })
        } else if defaults.object(forKey: Self.activeTripIDKey) == nil {
            // 구버전은 시작 시 준비 ID를 지웠습니다. 이 경우에만 최근 미완료 1건을 복구합니다.
            descriptor = FetchDescriptor(
                predicate: #Predicate { !$0.isDone },
                sortBy: [SortDescriptor(\Trip.createdAt, order: .reverse)]
            )
        } else {
            return
        }

        descriptor.fetchLimit = 1
        // 확정·시작 시 명시적으로 저장한 여행만 복원합니다.
        descriptor.includePendingChanges = false
        let trip = try context.fetch(descriptor).first

        // 저장 누락·삭제로 여행이 없어도 ID를 임의로 지우거나 다른 여행으로 바꾸지 않습니다.
        if tripID != nil && trip == nil {
            throw RestorationError.tripNotFound
        }

        if let trip, !trip.isDone {
            sessionTrip = trip
            updateActiveTripID(trip.id)
        } else {
            clearRestorationID()
        }
    }

    /// 경로 확정 직후 여행 준비 화면을 홈 탭의 루트로 보여 줍니다.
    func showTripReadyHome(for trip: Trip) {
        sessionTrip = trip
        clearLegacyReadyTripID()
        updateActiveTripID(trip.id)
        homeStackID = UUID()
        selectedTab = .home
    }

    /// 준비 화면에서 여행을 시작하면 이후 홈은 진행 중 상태로 표시합니다.
    func markTripAsStarted(_ tripID: UUID) {
        guard activeTripID == tripID else { return }
        clearLegacyReadyTripID()
    }

    /// 여행 흐름을 닫고 지정한 탭의 첫 화면으로 돌아갑니다.
    func finishTripFlow(returningTo tab: Tab) {
        sessionTrip = nil
        clearRestorationID()
        homeStackID = UUID()
        selectedTab = tab
    }

    /// 현재 미완료 여행만 삭제합니다. 저장 성공 전에는 화면·복원 상태를 바꾸지 않습니다.
    func cancelTrip(_ tripID: UUID, in context: ModelContext) throws {
        guard activeTripID == tripID, sessionTrip?.id == tripID else {
            throw TripCancellationError.notActive
        }

        // 다른 화면의 미저장 변경까지 저장하거나 rollback하지 않도록 삭제 작업을 격리합니다.
        let deletionContext = ModelContext(context.container)
        deletionContext.autosaveEnabled = false
        var descriptor = FetchDescriptor<Trip>(predicate: #Predicate { $0.id == tripID })
        descriptor.fetchLimit = 1
        guard let trip = try deletionContext.fetch(descriptor).first else {
            throw RestorationError.tripNotFound
        }
        guard !trip.isDone, sessionTrip?.isDone == false else {
            throw TripCancellationError.alreadyCompleted
        }

        // 연결된 RouteStop·TripPhoto만 cascade 삭제되고 기존 픽셀/다른 여행은 유지됩니다.
        deletionContext.delete(trip)
        try deletionContext.save()
        finishTripFlow(returningTo: .home)
    }

    enum TripCancellationError: LocalizedError {
        case notActive, alreadyCompleted

        var errorDescription: String? {
            switch self {
            case .notActive: "현재 진행 중인 여행이 아니에요. 홈에서 여행 상태를 확인해주세요."
            case .alreadyCompleted: "이미 완료한 여행은 중단할 수 없어요."
            }
        }
    }

    private func clearRestorationID() {
        clearLegacyReadyTripID()
        updateActiveTripID(nil)
    }

    private func clearLegacyReadyTripID() {
        tripReadyTripID = nil
        defaults.removeObject(forKey: Self.tripReadyTripIDKey)
    }

    private func updateActiveTripID(_ tripID: UUID?) {
        activeTripID = tripID
        // 빈 값은 "복원할 여행 없음"입니다. 키를 지우면 구버전 복구가 다시 실행됩니다.
        defaults.set(tripID?.uuidString ?? "", forKey: Self.activeTripIDKey)
    }

    enum RestorationError: LocalizedError {
        case tripNotFound

        var errorDescription: String? {
            "저장된 여행을 이 기기에서 찾을 수 없어요. 홈으로 돌아가 새 여행을 만들어주세요."
        }
    }
}
