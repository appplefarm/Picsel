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
    static let maximumRecommendationCount = 10

    var activeTrip: Trip
    
    var candidates: [PlaceDTO] = []       // 국문 관광정보 API로 받아올 추천 장소 최대 10곳
    var totalFetchedCount: Int = 0        // 10장 중 몇장째인지 계산하기 위한 전체 개수
    var selectedPlaces: [PlaceDTO] = []   // 오른쪽으로 스와이프(선택)한 장소들
    var isLoading: Bool = false
    var hasLoadedRecommendations: Bool = false

    /// 경로 확인 화면에 넘길 장소 사진입니다.
    /// RouteStop 모델에는 사진 필드가 없어 화면 사이에서만 들고 다닙니다.
    private(set) var thumbnailURLsByStopID: [UUID: URL] = [:]

    /// 수상작 목적지 사진입니다. 경유지와 달리 홈 화면에서 넘겨받습니다.
    private let destinationPhotoURL: URL?

    init(trip: Trip, destinationPhotoURL: URL? = nil) {
        self.activeTrip = trip
        self.destinationPhotoURL = destinationPhotoURL
    }
    
    // MARK: - 목적지와 동일한 시·군·구의 일반 관광지 추천
    func fetchRecommendedPlaces(areaCode: String, sigunguCode: String) async {
        isLoading = true
        hasLoadedRecommendations = false
        
        do {
            let fetchedData = try await TourAPIManager.shared.fetchRecommendedPlaces(
                areaCode: areaCode,
                sigunguCode: sigunguCode
            )
            try Task.checkCancellation()

            candidates = fetchedData
            totalFetchedCount = fetchedData.count
            hasLoadedRecommendations = true
            isLoading = false
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            print("국문 관광정보 추천 통신 에러: \(error.localizedDescription)")
            candidates = []
            totalFetchedCount = 0
            hasLoadedRecommendations = true
            isLoading = false
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
    
    // MARK: - 선택 초기화

    /// 골라 둔 경유지를 모두 비웁니다.
    ///
    /// 경로 확인 화면에서 뒤로 오면 추천 목록을 처음부터 다시 받습니다.
    /// 이때 앞서 고른 장소가 남아 있으면 새로 고른 장소가 그 위에 쌓여
    /// 경유지가 10곳, 20곳으로 계속 불어납니다.
    /// 목록을 새로 받을 때는 선택도 0곳에서 다시 시작하는 것이 맞습니다.
    func resetSelection() {
        selectedPlaces = []
        thumbnailURLsByStopID = [:]
        detachWaypoints()
    }

    /// 여행에 붙어 있던 경유지를 떼어냅니다. 목적지는 그대로 둡니다.
    private func detachWaypoints() {
        for stop in activeTrip.stops where !stop.isDestination {
            stop.trip = nil
            // 여행이 이미 저장된 뒤라면, 떼어낸 장소가 DB에 떠돌지 않게 함께 지웁니다.
            stop.modelContext?.delete(stop)
        }
        activeTrip.stops.removeAll { !$0.isDestination }
    }

    // MARK: - 최종 경로 확정 (DB에 반영)
    func finalizeWaypoints() {
        // 확인 화면에서 되돌아와 다시 확정해도 기존 경유지가 중복되지 않게 교체합니다.
        detachWaypoints()

        var thumbnails: [UUID: URL] = [:]

        // 임시로 모아둔 selectedPlaces를 RouteStop 엔티티로 변환하여 마스터 Trip에 꽂아 넣음
        for (index, place) in selectedPlaces.enumerated() {
            let newStop = RouteStop(
                placeId: place.id,
                name: place.name,
                latitude: place.latitude,
                longitude: place.longitude,
                stopType: "waypoint",
                orderIndex: index // 선택한 순서대로 인덱스 부여 (0, 1, 2...)
            )
            newStop.address = place.address
            newStop.regionCode = place.regionCode
            newStop.photoURL = place.photoURL

            // 양방향 연결
            newStop.trip = activeTrip
            activeTrip.stops.append(newStop)
            
            // 기존에 orderIndex가 0이었던 목적지는 맨 마지막으로 밀려나야 하므로 업데이트
            if let dest = activeTrip.destinationStop {
                dest.orderIndex = selectedPlaces.count
            }

            if let photoURL = place.photoURL, let url = URL(string: photoURL) {
                thumbnails[newStop.id] = url
            }
        }

        if let destinationStop = activeTrip.destinationStop, let destinationPhotoURL {
            thumbnails[destinationStop.id] = destinationPhotoURL
            // 홈에서 이미 넣어 두지만, 과거에 만들어진 여행에는 비어 있을 수 있습니다.
            if destinationStop.photoURL == nil {
                destinationStop.photoURL = destinationPhotoURL.absoluteString
            }
        }

        thumbnailURLsByStopID = thumbnails
    }

    // MARK: - 여행 계획 저장 (SwiftData 등록)

    /// 확정한 여행 계획을 SwiftData에 준비 상태로 등록합니다.
    ///
    /// 여기서 저장해 두지 않으면 실제 여행 중(몇 시간)에 앱이 메모리에서 내려갈 때
    /// 목적지·경유지·경로가 통째로 사라집니다.
    /// `startTime == nil`은 준비 중, 값이 있으면 진행 중이라는 상태로 사용합니다.
    @discardableResult
    func saveTripPlan(in context: ModelContext) -> Bool {
        // 경로 확정은 아직 실제 여행 시작이 아닙니다.
        // 이 값들이 SwiftData에 저장되어 앱 재실행 시 준비 화면으로 판별됩니다.
        activeTrip.startTime = nil
        activeTrip.endTime = nil
        activeTrip.isDone = false

        // 완료 화면에서 사용할 픽셀과 진행 중 홈의 도형이 같은 지역을 가리키게 합니다.
        // 목적지를 지운 여행은 새로 판정할 좌표가 없습니다.
        // 그럴 때 nil로 덮어쓰면 목적지를 고를 때 새겨 둔 지역까지 잃어버립니다.
        if let code = activeTrip.pixelTile?.code {
            activeTrip.targetPixelCode = code
        }

        // 뒤로 갔다가 다시 들어와도 두 번 등록되지 않게 확인합니다.
        if activeTrip.modelContext == nil {
            context.insert(activeTrip)
        }

        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            print("여행 저장에 실패했습니다: \(error.localizedDescription)")
            return false
        }
    }
}
