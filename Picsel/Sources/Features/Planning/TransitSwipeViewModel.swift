//
//  TransitSwipeViewModel.swift
//  Picsel
//
//  Created by 김나영 on 8/31/26.
//


import SwiftUI
import SwiftData

@Observable
final class TransitSwipeViewModel {
    // 1. 주입받을 마스터 여행 데이터
    var activeTrip: Trip
    
    // 2. 뷰에서 관리할 임시 상태 배열
    var candidates: [PlaceDTO] = []       // API로 받아올 추천 장소 최대 10곳
    var selectedPlaces: [PlaceDTO] = []   // 오른쪽으로 스와이프(선택)한 장소들
    
    var isLoading: Bool = false
    
    init(trip: Trip) {
        self.activeTrip = trip
    }
    
    // MARK: - API 통신 (한국관광공사 사진 갤러리 API)
    func fetchRecommendedPlaces(regionCode: Int) async {
        isLoading = true
        
        // TODO: 한국관광공사 API (https://www.data.go.kr/data/15101914/openapi.do) 호출 로직
        // URLSession을 통해 JSON 파싱 후 [PlaceDTO] 형태로 변환하여 candidates에 할당
        // 예시: let fetchedData = await NetworkManager.shared.getPhotos(areaCode: regionCode)
        // self.candidates = fetchedData.prefix(10).map { ... }
        
        // 2. 포항 관광지 목데이터
        let mockPlaces = [
            PlaceDTO(id: "P1", name: "호미곶 해맞이광장", address: "경북 포항시 남구", latitude: 36.0773, longitude: 129.5685, regionCode: 11111),
            PlaceDTO(id: "P2", name: "환호공원 스페이스워크", address: "경북 포항시 북구", latitude: 36.0646, longitude: 129.3903, regionCode: 11111),
            PlaceDTO(id: "P3", name: "영일대 해수욕장", address: "경북 포항시 북구", latitude: 36.0594, longitude: 129.3802, regionCode: 11111)
        ]
        
        // 3. 배열에 데이터 주입
        self.candidates = mockPlaces
        
        isLoading = false
    }
    
    // MARK: - 스와이프 액션 로직
    func swipeRight(on place: PlaceDTO) {
        // 선택한 장소를 임시 배열에 저장하고, 후보군에서 제거
        selectedPlaces.append(place)
        candidates.removeAll { $0.id == place.id }
    }
    
    func swipeLeft(on place: PlaceDTO) {
        // 안 끌리는 곳은 그냥 후보군에서 날려버림
        candidates.removeAll { $0.id == place.id }
    }
    
    // MARK: - 최종 경로 확정 (DB에 반영)
    func finalizeWaypoints() {
        // 임시로 모아둔 selectedPlaces를 RouteStop 엔티티로 변환하여 마스터 Trip에 꽂아 넣음
        for (index, place) in selectedPlaces.enumerated() {
            let newStop = RouteStop(
                placeId: place.id,
                name: place.name,
                latitude: place.latitude,
                longitude: place.longitude,
                stopType: "waypoint",
                orderIndex: index // 선택한 순서대로 인덱스 부여
            )
            // 양방향 연결
            newStop.trip = activeTrip
            activeTrip.stops.append(newStop)
        }
    }
}
