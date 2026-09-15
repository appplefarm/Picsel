//
//  AppRouter.swift
//  Picsel
//
//  Created by kosoobin on 9/11/26.
//

import Foundation

/// 탭 선택과 여행 흐름의 종료를 한곳에서 관리합니다.
///
/// 여행 기록을 마치고 "홈으로" / "픽셀맵 확인하기"를 누르면
/// 홈에서 쌓아 올린 화면(목적지 고르기 → 경유지 선택 → 경로 확인 → 여행 진행 → 기록 → 픽셀 획득)을
/// 전부 닫고 원하는 탭의 첫 화면으로 돌아가야 합니다.
/// 그 신호를 화면마다 클로저로 넘기는 대신 이 객체 하나로 전달합니다.
@Observable
final class AppRouter {

    private static let tripReadyTripIDKey = "picsel.tripReadyTripID"

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

    /// 경로를 확정했지만 아직 실제 여행을 시작하지 않은 여행 ID입니다.
    /// 강제 종료 후에도 준비 화면을 복원할 수 있도록 UserDefaults에 함께 저장합니다.
    private(set) var tripReadyTripID: UUID?

    init() {
        tripReadyTripID = UserDefaults.standard
            .string(forKey: Self.tripReadyTripIDKey)
            .flatMap(UUID.init(uuidString:))
    }

    /// 경로 확정 직후 여행 준비 화면을 홈 탭의 루트로 보여 줍니다.
    func showTripReadyHome(for tripID: UUID) {
        updateTripReadyTripID(tripID)
        homeStackID = UUID()
        selectedTab = .home
    }

    /// 준비 화면에서 여행을 시작하면 이후 홈은 진행 중 상태로 표시합니다.
    func markTripAsStarted(_ tripID: UUID) {
        guard tripReadyTripID == tripID else { return }
        updateTripReadyTripID(nil)
    }

    /// 여행 흐름을 닫고 지정한 탭의 첫 화면으로 돌아갑니다.
    func finishTripFlow(returningTo tab: Tab) {
        updateTripReadyTripID(nil)
        homeStackID = UUID()
        selectedTab = tab
    }

    private func updateTripReadyTripID(_ tripID: UUID?) {
        tripReadyTripID = tripID

        if let tripID {
            UserDefaults.standard.set(
                tripID.uuidString,
                forKey: Self.tripReadyTripIDKey
            )
        } else {
            UserDefaults.standard.removeObject(forKey: Self.tripReadyTripIDKey)
        }
    }
}
