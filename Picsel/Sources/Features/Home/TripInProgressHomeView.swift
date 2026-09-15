//
//  TripInProgressHomeView.swift
//  Picsel
//

import SwiftUI

/// 앱 재실행을 포함해 여행이 진행 중일 때 보여 주는 홈입니다.
struct TripInProgressHomeView: View {
    let cityName: String
    let regionCode: String?
    let onSettingsTapped: () -> Void
    let onTripProgressTapped: () -> Void

    init(
        cityName: String = "포항",
        regionCode: String? = "4711",
        onSettingsTapped: @escaping () -> Void = {},
        onTripProgressTapped: @escaping () -> Void = {}
    ) {
        self.cityName = cityName
        self.regionCode = regionCode
        self.onSettingsTapped = onSettingsTapped
        self.onTripProgressTapped = onTripProgressTapped
    }

    var body: some View {
        TripStatusHomeView(
            cityName: cityName,
            regionCode: regionCode,
            presentation: .inProgress,
            onSettingsTapped: onSettingsTapped,
            onPrimaryActionTapped: onTripProgressTapped
        )
    }
}

#Preview("여행 진행 중 홈") {
    TripInProgressHomeView()
}
