//
//  StaticModels.swift
//  Picxel
//
//  Created by 김나영 on 8/23/26.
//


import Foundation
import CoreLocation

// MARK: - "API 응답" 및 프리셋 장소 데이터 (Place + PresetPlace 통합)
// TODO: - API 담당자가 한번 더 수정해야 함.
struct PlaceDTO: Identifiable, Codable, Hashable {
    var id: String
    var name: String            // placeName
    var address: String
    var latitude: Double
    var longitude: Double
    var photoURL: String?       // URL(string:)으로 파싱하여 사용
    var detailDescription: String?
    var regionCode: String?     // targetPixelCode 역할 통합
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 지도에 그릴 폴리라인 좌표 (RoutePlan의 routePolyline)
struct RoutePoint: Codable {
    var latitude: Double
    var longitude: Double
}

// MARK: - 백지도 픽셀 격자 (PixelRegion)
struct PixelRegion: Identifiable {
    let id = UUID()
    let code: Int // 지역코드
    let name: String
    let gridX: Int
    let gridY: Int
}

let allPixelRegions: [PixelRegion] = [
    PixelRegion(code: 11111, name: "영덕", gridX: 2, gridY: 4),
    // ... 80개 세팅
]
