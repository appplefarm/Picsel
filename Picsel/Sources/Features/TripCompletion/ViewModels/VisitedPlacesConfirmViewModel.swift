import Foundation
import Observation

@Observable
final class VisitedPlacesConfirmViewModel {
    let trip: Trip
    let thumbnailURLsByStopID: [UUID: URL]
    
    // 방문 여부를 화면 내에서 토글 관리하기 위한 임시 Set
    var visitedStopIDs: Set<UUID>
    
    init(trip: Trip, thumbnailURLsByStopID: [UUID: URL]) {
        self.trip = trip
        self.thumbnailURLsByStopID = thumbnailURLsByStopID
        
        // 처음 진입 시 모든 경유지를 기본적으로 방문(체크)된 상태로 둡니다.
        // 유저가 방문하지 않은 곳만 체크 해제하도록 유도
        self.visitedStopIDs = Set(trip.stops.map { $0.id })
    }
    
    var stops: [RouteStop] {
        // 경유지 -> 최종 목적지 순서입니다.
        // Trip+RouteOrder의 orderedStops가 같은 규칙을 이미 담고 있어 그대로 씁니다.
        trip.orderedStops
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
