//
//  DatabaseModels.swift
//  Picxel
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
    var isDone: Bool            // false: 계획/진행중, true: 완료
    
    // 07~09 화면 (계획 단계 - TripPlan 데이터)
    var originLatitude: Double?
    var originLongitude: Double?
    var currentCandidateIndex: Int = 0
    var skippedWaypointIDs: [String] = []
    
    // 13 화면 (내비게이션 및 실시간 진행 - ActiveTrip 데이터)
    var currentPlaceIndex: Int = 0
    var remainingDistanceMeters: Double?
    var estimatedDurationSeconds: Double?
    
    // 17~19 화면 (최종 결과 - RoutePlan, PixelTrip 데이터)
    var totalDistanceMeters: Double?
    var totalDurationSeconds: Double?
    var routePolylineData: Data? // [RoutePoint]를 인코딩하여 저장
    var authPhotoData: [Data] = [] // 인증 사진들
    var targetPixelCode: String? // 해금할/해금된 픽셀 구역 코드
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \RouteStop.trip)
    var stops: [RouteStop] = []
    
    @Relationship(deleteRule: .cascade, inverse: \TripPhoto.trip)
    var photos: [TripPhoto] = []
    
    var pixel: UserPixel?
    
    init(title: String = "", originLat: Double? = nil, originLng: Double? = nil) {
        self.id = UUID()
        self.title = title
        self.memo = ""
        self.createdAt = Date()
        self.isDone = false
        self.originLatitude = originLat
        self.originLongitude = originLng
    }
    
    // MARK: - Computed Properties (상태 조회 및 타임라인 정렬용)
    var sortedStops: [RouteStop] { stops.sorted { $0.orderIndex < $1.orderIndex } }
    var visitedPlaces: [RouteStop] { sortedStops.filter { $0.isVisited } }
    var unvisitedPlaces: [RouteStop] { sortedStops.filter { !$0.isVisited } }
    
    var visitedPlacesCount: Int { visitedPlaces.count }
    var photoCount: Int { photos.count }
    
    var destination: RouteStop? { stops.first { $0.isDestination || $0.stopType == "destination" } }
    var waypoints: [RouteStop] { sortedStops.filter { $0.stopType == "waypoint" } }
    
    var currentTargetPlace: RouteStop? {
        guard currentPlaceIndex < sortedStops.count else { return nil }
        return sortedStops[currentPlaceIndex]
    }
    
    var mainRegionCode: String {
        return targetPixelCode ?? stops.last?.regionCode ?? ""
    }
}

// MARK: - 통합 경로 장소 모델 (RouteStop + VisitedPlace + VisitingPlace + PlannedPlace)
@Model
final class RouteStop {
    @Attribute(.unique) var id: UUID
    var placeId: String?
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    var regionCode: String?
    
    // TODO: 둘 중 하나로 합쳐도 될거같은뎅
    var stopType: String        // "origin", "waypoint", "destination"
    var isDestination: Bool
    
    // 진행 상황 및 순서 통제
    // TODO: 여기도 다시 확인
    var orderIndex: Int         // visitOrder
    var isVisited: Bool         // 방문 성공 여부
    
    // 점과 점 사이의 이동 과정 기록
    var movingTimeMinutes: Int? // 이전 장소로부터의 소요/이동 시간
    
    var trip: Trip?
    
    @Relationship(deleteRule: .nullify)
    var spotPhoto: TripPhoto?
    
    init(placeId: String? = nil, name: String, latitude: Double, longitude: Double, stopType: String, orderIndex: Int) {
        self.id = UUID()
        self.placeId = placeId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.stopType = stopType
        self.isDestination = (stopType == "destination")
        self.orderIndex = orderIndex
        self.isVisited = false
    }
}

// MARK: - 이미지 기록 (TripPhoto)
@Model
final class TripPhoto {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    var fileName: String?
    var createdAt: Date         // takenAt 통합
    
    var trip: Trip?
    
    init(imageData: Data, fileName: String? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.fileName = fileName
        self.createdAt = Date()
    }
}

// MARK: - 해금된 유저 픽셀 (UserPixel)
@Model
final class UserPixel {
    @Attribute(.unique) var regionCode: String
    var regionName: String
    var totalVisits: Int
    var acquiredDate: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Trip.pixel)
    var trips: [Trip] = []
    
    init(regionCode: String, regionName: String) {
        self.regionCode = regionCode
        self.regionName = regionName
        self.totalVisits = 1
        self.acquiredDate = Date()
    }
}
