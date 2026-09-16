//
//  TripReadyHomeView.swift
//  Picsel
//

import SwiftUI

/// 경로 확정 후 여행을 시작하기 전까지 보여 주는 여행 준비 홈입니다.
/// 준비 상태 ID가 저장되므로 앱을 강제 종료해도 이 화면으로 복원됩니다.
struct TripReadyHomeView: View {
    let cityName: String
    let regionCode: String?
    let onSettingsTapped: () -> Void
    let onStartTripTapped: () -> Void

    init(
        cityName: String = "포항",
        regionCode: String? = "4711",
        onSettingsTapped: @escaping () -> Void = {},
        onStartTripTapped: @escaping () -> Void = {}
    ) {
        self.cityName = cityName
        self.regionCode = regionCode
        self.onSettingsTapped = onSettingsTapped
        self.onStartTripTapped = onStartTripTapped
    }

    var body: some View {
        TripStatusHomeView(
            cityName: cityName,
            regionCode: regionCode,
            presentation: .ready,
            onSettingsTapped: onSettingsTapped,
            onPrimaryActionTapped: onStartTripTapped
        )
    }
}

#Preview("여행 준비 홈") {
    TripReadyHomeView()
}
