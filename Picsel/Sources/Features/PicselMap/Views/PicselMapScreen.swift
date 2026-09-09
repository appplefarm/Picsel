//
//  PicselMapScreen.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/8/26.
//

import SwiftData
import SwiftUI

/// 탭 진입점에서 저장된 기록을 읽고, 화면에는 표시용 값만 전달합니다.
struct PicselMapScreen: View {
    @Query private var pixels: [UserPixel]
    @Query(filter: #Predicate<Trip> { $0.isDone }) private var completedTrips: [Trip]

    var body: some View {
        PicselMapView(
            unlockedRegionCodes: Set(pixels.map { String($0.regionCode) }),
            records: completedTrips.compactMap { PicselMapRecord(trip: $0) }
                .sorted { $0.snapshot.travelDate > $1.snapshot.travelDate }
        )
    }
}
