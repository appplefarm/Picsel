//
//  LivePhotoDestinationService.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import Foundation
import OSLog

/// 관광공사 API에서 사진을 실시간으로 받고, CloudKit의 좌표와 짝지어 목적지 후보를 만듭니다.
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
    private let logger = Logger(subsystem: "com.applefarm.picsel", category: "PhotoDestination")

    init(
        awardService: AwardPhotoService = AwardPhotoService(),
        galleryService: GalleryPhotoService = GalleryPhotoService()
    ) {
        self.awardService = awardService
        self.galleryService = galleryService
    }

    func fetchDestinations(limit: Int) async throws -> [PhotoDestination] {
        guard limit > 0 else { return [] }

        // ① 좌표를 먼저 확보합니다.
        //    어떤 사진을 쓸지가 여기서 정해지고, 갤러리 API에 넘길 ID 목록도 여기서 나옵니다.
        let catalog = await PhotoCoordinateCatalogStore.shared.catalog()

        guard !catalog.isEmpty else {
            throw PhotoDestinationError.missingCoordinates
        }

        // ② 두 API를 동시에 부릅니다. 순서대로 부르면 기다리는 시간이 두 배가 됩니다.
        async let awardResult = load(.award) {
            try await awardService.fetchAll()
        }
        async let galleryResult = load(.gallery) {
            try await galleryService.fetch(
                matching: catalog.photoIDs(of: .gallery),
                // 섞어서 고를 여유를 두려고 넉넉히 받습니다.
                minimumCount: limit * 2
            )
        }

        let results = await [awardResult, galleryResult]
        let remotePhotos = results.flatMap { (try? $0.get()) ?? [] }

        // ③ 한쪽이 실패해도 나머지로 화면을 채웁니다. 둘 다 실패했을 때만 오류를 올립니다.
        guard !remotePhotos.isEmpty else {
            if let failure = results.compactMap(\.failureError).first {
                throw failure
            }
            throw PhotoDestinationError.noMatchingPhotos
        }

        // ④ 사진 정보와 좌표를 짝짓습니다.
        let destinations = remotePhotos.compactMap { photo in
            catalog
                .coordinate(forPhotoID: photo.photoID, source: photo.source)
                .map { destination(photo: photo, place: $0) }
        }

        logger.info("후보 \(destinations.count)곳 (API \(remotePhotos.count)장 중)")

        guard !destinations.isEmpty else {
            throw PhotoDestinationError.noMatchingPhotos
        }

        // ⑤ 섞어서 필요한 만큼만 돌려줍니다.
        //    안 섞으면 수상작이 항상 앞에 몰려 매번 같은 사진부터 보게 됩니다.
        return Array(destinations.shuffled().prefix(limit))
    }

    // MARK: - 짝짓기

    private func destination(
        photo: RemotePhoto,
        place: PhotoCoordinate
    ) -> PhotoDestination {
        PhotoDestination(
            id: photo.id,
            // 촬영지 글("정선군 남면, 민둥산")보다 팀이 찍어 둔 장소명이 구체적입니다.
            name: place.placeName,
            photoURL: photo.displayImageURL.absoluteString,
            detailDescription: photo.title,
            regionCode: Int(place.regionCode),
            address: place.address,
            latitude: place.latitude,
            longitude: place.longitude
        )
    }

    // MARK: - 부분 실패 허용

    /// 실패해도 던지지 않고 담아 둡니다. 한쪽 API가 죽어도 화면은 떠야 합니다.
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

nonisolated enum PhotoDestinationError: LocalizedError {
    case missingCoordinates
    case noMatchingPhotos

    var errorDescription: String? {
        switch self {
        case .missingCoordinates:
            "사진 위치 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요."
        case .noMatchingPhotos:
            "지금 보여드릴 사진을 찾지 못했어요."
        }
    }
}

private extension Result {
    /// 실패했을 때의 오류만 꺼냅니다.
    var failureError: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}
