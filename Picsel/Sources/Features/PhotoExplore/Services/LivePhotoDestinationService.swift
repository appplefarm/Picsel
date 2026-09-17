//
//  LivePhotoDestinationService.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import CoreLocation
import Foundation
import OSLog

/// 관광공사의 수상작·관광사진 API에서 고화질 사진을 실시간으로 받고,
/// 반경 안의 CloudKit 좌표와 짝지어 목적지 후보를 만듭니다.
///
/// 두 조각이 만나야 화면에 띄울 수 있습니다.
///
/// | | 어디서 | 저장 |
/// |---|---|---|
/// | 제목·이미지 주소·촬영지 | 관광공사 API | 안 함 (공모전 규정: 실시간 호출) |
/// | 좌표·지역코드·장소명 | CloudKit public DB | 함 (API가 주지 않는 우리 데이터) |
///
/// 짝이 없는 사진은 버립니다.
/// 좌표가 없으면 지도에 찍을 수 없고, API에 없는 사진은 띄울 권리가 없습니다.
nonisolated struct LivePhotoDestinationService: PhotoDestinationService {

    private let awardService: AwardPhotoService
    private let galleryService: GalleryPhotoService
    private let originLocation: CLLocation?
    private let selectedRadiusMeters: CLLocationDistance
    private let logger = Logger(subsystem: "com.applefarm.picsel", category: "PhotoDestination")

    init(
        originLocation: CLLocation?,
        selectedRadiusMeters: CLLocationDistance,
        awardService: AwardPhotoService = AwardPhotoService(),
        galleryService: GalleryPhotoService = GalleryPhotoService()
    ) {
        self.originLocation = originLocation
        self.selectedRadiusMeters = selectedRadiusMeters.isFinite
            ? max(selectedRadiusMeters, PhotoRecommendationPolicy.minimumRadiusMeters)
            : PhotoRecommendationPolicy.minimumRadiusMeters
        self.awardService = awardService
        self.galleryService = galleryService
    }

    func fetchDestinations(limit: Int) async throws -> [PhotoDestination] {
        guard limit > 0 else { return [] }

        guard let originLocation,
              CLLocationCoordinate2DIsValid(originLocation.coordinate) else {
            throw PhotoDestinationError.missingOrigin
        }

        // ① 좌표를 먼저 확보하고 award와 gallery 모두 선택 반경 안의 후보로 남깁니다.
        let catalog = await PhotoCoordinateCatalogStore.shared.catalog()

        guard !catalog.isEmpty else {
            throw PhotoDestinationError.missingCoordinates
        }

        let coordinates = PhotoRecommendationPolicy.photoExploreCoordinates(
            in: catalog,
            from: originLocation,
            radiusMeters: selectedRadiusMeters
        )

        // 반경 안 후보가 없으면 네트워크 오류가 아닌 정상적인 Empty 결과입니다.
        guard !coordinates.isEmpty else { return [] }

        let awardPhotoIDs = Set(
            coordinates.lazy.filter { $0.source == .award }.map(\.photoID)
        )
        let galleryPhotoIDs = Set(
            coordinates.lazy.filter { $0.source == .gallery }.map(\.photoID)
        )

        // ② 제목과 고화질 이미지 주소는 각 관광공사 API에서 실시간으로 받습니다.
        async let awardResult = load(.award) {
            guard !awardPhotoIDs.isEmpty else { return [] }
            return try await awardService.fetchAll()
        }
        async let galleryResult = load(.gallery) {
            guard !galleryPhotoIDs.isEmpty else { return [] }
            return try await galleryService.fetch(
                matching: galleryPhotoIDs,
                minimumCount: min(galleryPhotoIDs.count, max(limit * 2, limit))
            )
        }

        let results = await [awardResult, galleryResult]
        let remotePhotos = results.flatMap { (try? $0.get()) ?? [] }
        try Task.checkCancellation()

        guard !remotePhotos.isEmpty else {
            if let failure = results.compactMap(\.failureError).first {
                throw failure
            }
            return []
        }

        // ③ source와 photoID가 모두 일치하는 후보만 섞고 최대 7개를 반환합니다.
        let destinations = PhotoRecommendationPolicy.photoExploreDestinations(
            coordinates: coordinates,
            remotePhotos: remotePhotos,
            limit: limit
        )

        logger.info(
            "반경 후보 \(coordinates.count)장 → 표시 가능 \(destinations.count)장"
        )
        return destinations
    }

    /// 한쪽 API가 일시적으로 실패해도 다른 출처의 사진은 계속 사용할 수 있게 합니다.
    private func load(
        _ source: PhotoAPISource,
        _ operation: () async throws -> [RemotePhoto]
    ) async -> Result<[RemotePhoto], Error> {
        do {
            return .success(try await operation())
        } catch {
            logger.error("\(source.rawValue) 실패: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}

private extension Result {
    var failureError: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}

nonisolated enum PhotoDestinationError: LocalizedError {
    case missingCoordinates
    case missingOrigin
    case noMatchingPhotos

    var errorDescription: String? {
        switch self {
        case .missingCoordinates:
            "사진 위치 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요."
        case .missingOrigin:
            "현재 위치를 확인할 수 없어 주변 사진을 추천할 수 없어요."
        case .noMatchingPhotos:
            "지금 보여드릴 사진을 찾지 못했어요."
        }
    }
}
