//
//  PicselMapRecord.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/8/26.
//

import Foundation

/// 기존 Trip 모델을 최근 픽셀 카드와 PixelDetailView에 전달하는 표시용 값입니다.
struct PicselMapRecord: Identifiable {
    let id: UUID
    let regionCode: String
    let snapshot: TripRecordSnapshot
    let stops: [RouteStopDisplay]
    /// 기록 상세에서 제목·내용·사진을 고치려면 저장된 원본이 필요합니다.
    /// 목업 데이터로 만든 기록은 nil이라 편집 버튼이 보이지 않습니다.
    let trip: Trip?

    init(
        id: UUID,
        regionCode: String,
        snapshot: TripRecordSnapshot,
        stops: [RouteStopDisplay],
        trip: Trip? = nil
    ) {
        self.id = id
        self.regionCode = regionCode
        self.snapshot = snapshot
        self.stops = stops
        self.trip = trip
    }

    init?(trip: Trip) {
        guard trip.isDone,
              let regionCode = trip.pixel.map({ String($0.regionCode) }) ?? trip.targetPixelCode,
              !regionCode.isEmpty else { return nil }

        // 기록 화면과 같은 기준을 써야 같은 여행이 화면마다 다르게 보이지 않습니다.
        let visitedStops = trip.recordedStops
        self.init(
            id: trip.id,
            regionCode: regionCode,
            snapshot: TripRecordSnapshot(
                regionName: trip.recordRegionName,
                title: trip.title,
                memo: trip.memo,
                travelDate: trip.recordDate,
                photoDataList: trip.photos.sorted { $0.orderIndex < $1.orderIndex }.map(\.imageData),
                placeCount: visitedStops.count,
                destinationPhotoURL: trip.representativePhotoURL
            ),
            // 현재 RouteStop에 이동 시간/방문 순서 필드가 없어 값을 만들지 않습니다.
            stops: visitedStops.map { RouteStopDisplay(name: $0.name, travelMinutesToNext: nil) },
            trip: trip
        )
    }
}
