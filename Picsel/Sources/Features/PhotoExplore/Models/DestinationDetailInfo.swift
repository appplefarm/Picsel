//
//  DestinationDetailInfo.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import Foundation

/// 목적지 상세 화면에만 필요한 부가 정보입니다.
/// 현재 없는 위치·경로 값은 `nil`로 두고, 서버 데이터가 생기면 주입합니다.
struct DestinationDetailInfo {
    let locationName: String?
    let distanceKilometers: Double?
    let estimatedDurationMinutes: Int?
    let categoryName: String?

    init(
        destination: PhotoDestination,
        distanceKilometers: Double? = nil,
        estimatedDurationMinutes: Int? = nil
    ) {
        locationName = destination.address
        self.distanceKilometers = distanceKilometers
        self.estimatedDurationMinutes = estimatedDurationMinutes
        categoryName = "관광공모전 수상작"
    }

    var chips: [String] {
        [distanceText, durationText, categoryName]
            .compactMap { value in
                guard let value,
                      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return value
            }
    }

    private var distanceText: String? {
        guard let distanceKilometers else { return nil }
        let distance = distanceKilometers.formatted(
            .number.precision(.fractionLength(0...1))
        )
        return "현재 위치에서 \(distance)km"
    }

    private var durationText: String? {
        guard let estimatedDurationMinutes else { return nil }

        let hours = estimatedDurationMinutes / 60
        let minutes = estimatedDurationMinutes % 60

        switch (hours, minutes) {
        case (0, let minutes):
            return "약 \(minutes)분"
        case (let hours, 0):
            return "약 \(hours)시간"
        default:
            return "약 \(hours)시간 \(minutes)분"
        }
    }
}
