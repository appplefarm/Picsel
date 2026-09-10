//
//  DebugPhotoCatalogClient.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/10/26.
//

import Foundation

#if DEBUG
/// 실패·빈 응답·지연·미검증 장소를 재현합니다. Release에서는 컴파일하지 않습니다.
struct DebugPhotoCatalogClient: PhotoCatalogClient {
    enum Scenario: Sendable {
        case success, empty, failure, validation
    }

    var bundle: Bundle = .main
    var scenario: Scenario = .success
    var delay: Duration = .milliseconds(350)

    func fetchCatalog() async throws -> PhotoCatalogResponse {
        try await Task.sleep(for: delay)
        try Task.checkCancellation()

        switch scenario {
        case .empty:
            return PhotoCatalogResponse(schemaVersion: 1, photos: [])
        case .failure:
            throw URLError(.notConnectedToInternet)
        case .success:
            return try await BundledPhotoCatalogClient(bundle: bundle).fetchCatalog()
        case .validation:
            let catalog = try await BundledPhotoCatalogClient(bundle: bundle).fetchCatalog()
            var photos = catalog.photos
            // 기존 20개 응답의 순서를 재현해 상세 화면의 확정 차단을 검증합니다.
            photos.insert(Self.unverifiedPhoto, at: min(6, photos.count))
            let response = PhotoCatalogResponse(schemaVersion: catalog.schemaVersion, photos: photos)
            return response
        }
    }

    /// 원본 시트의 보류 건입니다. 원본 좌표를 보존하되 실제 목적지로 사용하지 않습니다.
    static let unverifiedPhoto = PhotoCatalogPhoto(
        source: "tourPhotoGallery",
        photoID: "3543624",
        photoTitle: "내연산",
        photoURL: "https://tong.visitkorea.or.kr/cms2/website/24/3543624.jpg",
        thumbnailURL: "https://tong.visitkorea.or.kr/cms2/website/24/3543624.jpg",
        placeName: "내연산",
        address: "경상북도 포항시 북구",
        sourceRegionCode: "47",
        shootingMonth: "202506",
        latitude: 36.2786758,
        longitude: 129.2899056,
        regionCode: nil,
        locationConfirmed: false
    )
}
#endif
