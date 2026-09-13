import Foundation
import Observation

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
        
        // 처음에는 완료 버튼 비활성화 상태 (아무것도 방문 처리 안됨)
        self.visitedStopIDs = []
        // 처음 순서는 원래 순서의 역순 (마지막 원소가 가장 처음 방문지)
        self.displayStops = trip.orderedStops.reversed()
    }
    
    // 현재 맨 위에 있는(마지막 원소) 카드를 맨 아래(첫 번째)로 보내는 함수
    func sendTopCardToBack() {
        guard !displayStops.isEmpty else { return }
        let topCard = displayStops.removeLast()
        displayStops.insert(topCard, at: 0)
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
        for stop in trip.stops {
            stop.isVisited = visitedStopIDs.contains(stop.id)
        }
    }
}
