//
//  TripRecordSnapshot.swift
//  Picsel
//
//  화면 사이로 여행 기록을 넘기기 위한 전달용 값.
//  SwiftData를 붙이기 전까지 TripRecordView -> PixelUnlockedView -> PixelDetailView를 잇는다.
//  나중에는 Trip에서 이 값을 만들어 넘기기만 하면 되므로 뷰 코드는 그대로 살아남는다.
//

import Foundation

struct TripRecordSnapshot {
    let regionName: String          // "영덕"
    let title: String
    let memo: String
    let travelDate: Date
    let photoDataList: [Data]
    let placeCount: Int

    var photoCount: Int { photoDataList.count }
    var representativePhotoData: Data? { photoDataList.first }
}

extension TripRecordSnapshot {
    /// Preview / 목업용 더미
    static let sample = TripRecordSnapshot(
        regionName: "영덕",
        title: "영덕 바다 따라가는 하루",
        memo: "이건 여행에 대한 간단한 메모입니다. 150자 이상 쓸 수 없어요. 본가에 있으니 기분이 좋다. 이번 여행 참 좋았다!",
        travelDate: .now,
        photoDataList: [],
        placeCount: 3
    )
}
