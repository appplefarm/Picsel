//
//  DestinationDetailInfo.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import Foundation

/// 목적지 상세 화면에만 필요한 부가 정보입니다.
/// 경로 조회 전에는 `nil`로 두고, 길찾기 응답의 거리·시간을 주입합니다.
struct DestinationDetailInfo {
    let locationName: String?
    let distanceKilometers: Double?
    let estimatedDurationMinutes: Int?

    init(
        destination: PhotoDestination,
        distanceKilometers: Double? = nil,
        estimatedDurationMinutes: Int? = nil
    ) {
        locationName = destination.address
        self.distanceKilometers = distanceKilometers
        self.estimatedDurationMinutes = estimatedDurationMinutes
    }

    var chips: [String] {
        [distanceText, durationText]
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
