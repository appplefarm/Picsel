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
    
    var candidates: [PlaceDTO] = []       // gallery API로 받아올 추천 장소 최대 10곳
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
    
    // MARK: - 목적지와 동일한 시·군·구의 관광사진 추천
    func fetchRecommendedPlaces(areaCode: String, sigunguCode: String) async {
        isLoading = true
        hasLoadedRecommendations = false
        
        do {
            let catalog = await PhotoCoordinateCatalogStore.shared.catalog()
            try Task.checkCancellation()

            // 관광공사 areaCd/sigunguCd와 카탈로그의 5자리 regionCode는 체계가 다릅니다.
            // 기존 RegionCodeManager로 각 주소를 판별해 같은 시·군·구만 유지합니다.
            let regionalPhotos = catalog.photos.filter { photo in
                guard photo.source == .gallery,
                      let region = RegionCodeManager.shared.findRegion(by: photo.address)
                else { return false }

                return region.areaCd == areaCode && region.sigunguCd == sigunguCode
            }

            let regionalCatalog = PhotoCoordinateCatalog(
                schemaVersion: catalog.schemaVersion,
                photos: regionalPhotos
            )
            let coordinates = PhotoRecommendationPolicy.galleryCoordinates(in: regionalCatalog)
            let wantedPhotoIDs = Set(coordinates.map(\.photoID))
            let requestedCount = min(
                wantedPhotoIDs.count,
                Self.maximumRecommendationCount
            )

            let remotePhotos = try await GalleryPhotoService().fetch(
                matching: wantedPhotoIDs,
                minimumCount: requestedCount
            )
            try Task.checkCancellation()

            let fetchedData = PhotoRecommendationPolicy.galleryDestinations(
                coordinates: coordinates,
                remotePhotos: remotePhotos,
                limit: Self.maximumRecommendationCount
            )
            .compactMap(\.placeDTO)

            candidates = fetchedData
            totalFetchedCount = fetchedData.count
            hasLoadedRecommendations = true
            isLoading = false
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            print("Gallery 추천 통신 에러: \(error.localizedDescription)")
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

    // MARK: - 여행 시작 (SwiftData 등록)

    /// 여행을 SwiftData에 등록하고 시작 시각을 남깁니다.
    ///
    /// 여기서 저장해 두지 않으면 실제 여행 중(몇 시간)에 앱이 메모리에서 내려갈 때
    /// 목적지·경유지·경로가 통째로 사라집니다.
    /// 목적지를 눌러보기만 한 여행이 쌓이지 않도록, 경로를 확정한 이 시점에 넣습니다.
    @discardableResult
    func startTrip(in context: ModelContext) -> Bool {
        if activeTrip.startTime == nil {
            activeTrip.startTime = Date()
        }

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
