//
//  LivePhotoDestinationService.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import CoreLocation
import Foundation
import OSLog

/// 관광공사 수상작 API에서 사진을 실시간으로 받고, 반경 안의 CloudKit 좌표와 짝지어 목적지 후보를 만듭니다.
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
    private let originLocation: CLLocation?
    private let selectedRadiusMeters: CLLocationDistance
    private let logger = Logger(subsystem: "com.applefarm.picsel", category: "PhotoDestination")

    init(
        originLocation: CLLocation?,
        selectedRadiusMeters: CLLocationDistance,
        awardService: AwardPhotoService = AwardPhotoService()
    ) {
        self.originLocation = originLocation
        self.selectedRadiusMeters = selectedRadiusMeters.isFinite
            ? max(selectedRadiusMeters, PhotoRecommendationPolicy.minimumRadiusMeters)
            : PhotoRecommendationPolicy.minimumRadiusMeters
        self.awardService = awardService
    }

    func fetchDestinations(limit: Int) async throws -> [PhotoDestination] {
        guard limit > 0 else { return [] }

        guard let originLocation,
              CLLocationCoordinate2DIsValid(originLocation.coordinate) else {
            throw PhotoDestinationError.missingOrigin
        }

        // ① 좌표를 먼저 확보하고 수상작 중 선택 반경 안의 후보만 남깁니다.
        let catalog = await PhotoCoordinateCatalogStore.shared.catalog()

        guard !catalog.isEmpty else {
            throw PhotoDestinationError.missingCoordinates
        }

        let coordinates = PhotoRecommendationPolicy.awardCoordinates(
            in: catalog,
            from: originLocation,
            radiusMeters: selectedRadiusMeters
        )

        // 반경 안 후보가 없으면 네트워크 오류가 아닌 정상적인 Empty 결과입니다.
        guard !coordinates.isEmpty else { return [] }

        // ② 실제 표시할 제목과 이미지 주소는 공모전 규정에 따라 API에서 실시간으로 받습니다.
        let remotePhotos = try await awardService.fetchAll()
        try Task.checkCancellation()

        // ③ API와 결합 가능한 후보만 섞고 최대 7개를 반환합니다.
        let destinations = PhotoRecommendationPolicy.destinations(
            coordinates: coordinates,
            remotePhotos: remotePhotos,
            limit: limit
        )

        logger.info(
            "반경 후보 \(coordinates.count)장 → 표시 가능 \(destinations.count)장"
        )
        return destinations
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
