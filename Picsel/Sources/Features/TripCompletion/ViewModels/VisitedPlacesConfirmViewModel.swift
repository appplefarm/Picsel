import Foundation
import Observation
import SwiftData

@Observable
final class VisitedPlacesConfirmViewModel {
    let trip: Trip
    let thumbnailURLsByStopID: [UUID: URL]
    
    // 방문 여부를 화면 내에서 토글 관리하기 위한 임시 Set
    var visitedStopIDs: Set<UUID>
    
    // 화면에 그릴 카드 순서 (맨 마지막 원소가 화면상 맨 위에 옴)
    var displayStops: [RouteStop]
    
    init(trip: Trip, thumbnailURLsByStopID: [UUID: URL]) {
        self.trip = trip
        self.thumbnailURLsByStopID = thumbnailURLsByStopID
        
        self.visitedStopIDs = []
        // 처음 순서는 원래 순서의 역순 (마지막 원소가 가장 처음 방문지)
        self.displayStops = trip.orderedStops.reversed()
    }
    
    // 현재 맨 위에 있는(마지막 원소) 카드를 맨 아래(첫 번째)로 보내는 함수 (다음 카드로 넘어감)
    func sendTopCardToBack() {
        guard !displayStops.isEmpty else { return }
        let topCard = displayStops.removeLast()
        displayStops.insert(topCard, at: 0)
    }
    
    // 맨 아래에 있는(첫 번째) 카드를 맨 위(마지막 원소)로 가져오는 함수 (이전 카드로 돌아감)
    func sendBottomCardToFront() {
        guard !displayStops.isEmpty else { return }
        let bottomCard = displayStops.removeFirst()
        displayStops.append(bottomCard)
    }
    
    func toggleVisited(for stopID: UUID) {
        if visitedStopIDs.contains(stopID) {
            visitedStopIDs.remove(stopID)
        } else {
            visitedStopIDs.insert(stopID)
        }
    }
    
    func isVisited(stopID: UUID) -> Bool {
        visitedStopIDs.contains(stopID)
    }
    
    // 다음 화면으로 넘어갈 때 실제 모델에 데이터 반영
    func confirmVisitedPlaces() {
        // 방문하지 않은 장소 찾아서 Context에서 완전 삭제
        let unvisitedStops = trip.stops.filter { !visitedStopIDs.contains($0.id) }
        for stop in unvisitedStops {
            stop.modelContext?.delete(stop)
        }
        
        // Trip 관계에서도 제거
        trip.stops.removeAll { !visitedStopIDs.contains($0.id) }
        
        // 남은 장소들은 방문 처리
        for stop in trip.stops {
            stop.isVisited = true
        }
    }
}
