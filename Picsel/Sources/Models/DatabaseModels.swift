//
//  DatabaseModels.swift
//  Picsel
//
//  Created by 김나영 on 8/23/26.
//


import Foundation
import SwiftData

// MARK: - 통합 여행 마스터 모델 (TripPlan + Trip + ActiveTrip + RoutePlan + TripRecord)
@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var title: String           // tripTitle
    var memo: String            // content
    
    // 시간 통제
    var createdAt: Date
    var startTime: Date?
    var endTime: Date?
    
    // 상태 관리
    // TODO: 함수로 빼고싶으면 빼기
    var isDone: Bool            // false: 계획/진행중, true: 완료
    
    // 17~19 화면 (최종 결과 - RoutePlan, PixelTrip 데이터)
    var totalDistanceMeters: Double?
    var targetPixelCode: String? // 해금할/해금된 픽셀 구역 코드
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \RouteStop.trip)
    var stops: [RouteStop] = []
    
    @Relationship(deleteRule: .cascade, inverse: \TripPhoto.trip)
    var photos: [TripPhoto] = []
    
    // TODO: 빼도 되는지 모르겠음
    var pixel: UserPixel?
    
    init(title: String = "", originLat: Double? = nil, originLng: Double? = nil) {
        self.id = UUID()
        self.title = title
        self.memo = ""
        self.createdAt = Date()
        self.isDone = false
    }
    
    // MARK: - Computed Properties (상태 조회 및 타임라인 정렬용)
    // TODO: ViewModel에 들어가는게 나을거 같아요
//    var sortedStops: [RouteStop] { stops.sorted { $0.orderIndex < $1.orderIndex } }
//    var visitedPlaces: [RouteStop] { sortedStops.filter { $0.isVisited } } // 한 여행에서 간 장소들 (경유지+목적지)
//    var unvisitedPlaces: [RouteStop] { sortedStops.filter { !$0.isVisited } } // 짜여진 여행에서 안 간(건너뛴) 장소들
//    
//    var visitedPlacesCount: Int { visitedPlaces.count }
//    var photoCount: Int { photos.count }
}

// MARK: - (장소 하나: 경유지or목적지) 통합 경로 장소 모델 (RouteStop + VisitedPlace + VisitingPlace + PlannedPlace)
@Model
final class RouteStop {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    var regionCode: Int?
    var isDestination: Bool
    
    // 진행 상황 및 순서 통제
    // TODO: 뺄까 했지만 일단 냅둠
    var isVisited: Bool         // 방문 성공 여부
    
    var trip: Trip?
    
    init(placeId: String? = nil, name: String, latitude: Double, longitude: Double, stopType: String, orderIndex: Int) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.isDestination = (stopType == "destination")
        self.isVisited = false
    }
}

// MARK: - 이미지 기록 (TripPhoto)
@Model
final class TripPhoto {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    var orderIndex: Int
    
    var trip: Trip?
    
    init(imageData: Data, orderIndex: Int) {
        self.id = UUID()
        self.imageData = imageData
        self.orderIndex = orderIndex
    }
}

// MARK: - 해금된 유저 픽셀 (UserPixel)
@Model
final class UserPixel {
    @Attribute(.unique) var regionCode: Int
    var regionName: String
    var totalVisits: Int
//    var acquiredDate: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Trip.pixel)
    var trips: [Trip] = []
    
    init(regionCode: Int, regionName: String) {
        self.regionCode = regionCode
        self.regionName = regionName
        self.totalVisits = 1
//        self.acquiredDate = Date()
    }
}
