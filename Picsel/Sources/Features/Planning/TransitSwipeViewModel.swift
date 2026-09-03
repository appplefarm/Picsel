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
    var activeTrip: Trip
    
    var candidates: [PlaceDTO] = []       // API로 받아올 추천 장소 최대 10곳
    var selectedPlaces: [PlaceDTO] = []   // 오른쪽으로 스와이프(선택)한 장소들
    var isLoading: Bool = false
    
    init(trip: Trip) {
        self.activeTrip = trip
    }
    
    // MARK: - API 통신 (한국관광공사 지역기반 API)
    func fetchRecommendedPlaces(areaCode: String, sigunguCode: String) async {
        isLoading = true
        
        do {
            let fetchedData = try await TourAPIManager.shared.fetchRecommendedPlaces(areaCode: areaCode, sigunguCode: sigunguCode)
            
            // UI 스레드(Main Actor)에서 상태 업데이트
            await MainActor.run {
                self.candidates = fetchedData
                self.isLoading = false
            }
        } catch {
            print("API 통신 에러: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
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
        // 확인 화면에서 되돌아와 다시 확정해도 기존 경유지가 중복되지 않게 교체합니다.
        for stop in activeTrip.stops where !stop.isDestination {
            stop.trip = nil
        }
        activeTrip.stops.removeAll { !$0.isDestination }

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
