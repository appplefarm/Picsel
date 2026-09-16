//
//  TransitSwipeViewModel.swift
//  Picsel
//
//  Created by 김나영 on 8/31/26.
//


import SwiftUI
import SwiftData

@MainActor
@Observable
final class TransitSwipeViewModel {
    enum LoadState {
        case idle, loading, loaded, failed(RequestFailure)
    }
    static let maximumRecommendationCount = 10

    var activeTrip: Trip
    
    var candidates: [PlaceDTO] = []       // 국문 관광정보 API로 받아올 추천 장소 최대 10곳
    var totalFetchedCount: Int = 0        // 10장 중 몇장째인지 계산하기 위한 전체 개수
    var selectedPlaces: [PlaceDTO] = []   // 오른쪽으로 스와이프(선택)한 장소들
    var loadState: LoadState = .idle
    private let service: TourAPIManager
    @ObservationIgnored private var requestTask: Task<[PlaceDTO], Error>?
    private var requestID: UUID?

    /// 경로 확인 화면에 넘길 장소 사진입니다.
    /// 재실행 후에는 RouteStop.photoURL에서 복원합니다.
    private(set) var thumbnailURLsByStopID: [UUID: URL] = [:]

    /// 수상작 목적지 사진입니다. 경유지와 달리 홈 화면에서 넘겨받습니다.
    private let destinationPhotoURL: URL?

    init(trip: Trip, destinationPhotoURL: URL? = nil, service: TourAPIManager? = nil) {
        self.activeTrip = trip
        self.destinationPhotoURL = destinationPhotoURL
        self.service = service ?? .shared
    }
    
    // MARK: - 목적지와 동일한 시·군·구의 일반 관광지 추천
    func fetchRecommendedPlaces(areaCode: String, sigunguCode: String) async {
        switch loadState {
        case .loaded: return // 뒤로 돌아와도 이미 고른/넘긴 카드가 다시 생기지 않습니다.
        case .loading where requestTask?.isCancelled != true: return
        case .loading: break
        case .idle, .failed: break
        }
        let id = UUID()
        requestID = id
        loadState = .loading
        let service = service
        let task = Task {
            try await service.fetchRecommendedPlaces(
                areaCode: areaCode,
                sigunguCode: sigunguCode
            )
        }
        requestTask = task
        defer { if requestID == id { requestTask = nil } }

        do {
            let fetchedData = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            try Task.checkCancellation()
            guard requestID == id else { return }

            candidates = fetchedData
            totalFetchedCount = fetchedData.count
            loadState = .loaded
        } catch {
            guard requestID == id else { return }
            if Task.isCancelled || RequestFailure.isCancellation(error) {
                loadState = .idle
            } else {
                loadState = .failed(RequestFailure(error))
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
            // 여행이 이미 저장된 뒤라면, 떼어낸 장소가 DB에 떠돌지 않게 함께 지웁니다.
            stop.modelContext?.delete(stop)
        }
        activeTrip.stops.removeAll { !$0.isDestination }

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
        activeTrip.targetPixelCode = activeTrip.pixelTile?.code

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
