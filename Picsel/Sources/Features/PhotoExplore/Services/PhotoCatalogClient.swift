//
//  PhotoCatalogClient.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/10/26.
//

import Foundation

/// 사진 API 정보와 팀이 입력한 장소 정보를 함께 제공하는 서버의 읽기 인터페이스.
/// 지금은 번들 JSON이 응답하며, 이후 CloudKit 구현으로 교체합니다.
protocol PhotoCatalogClient: Sendable {
    func fetchCatalog() async throws -> PhotoCatalogResponse
}

/// 서버 담당자와 합의할 임시 응답 규격. 공용 PlaceDTO/SwiftData 모델과 분리합니다.
struct PhotoCatalogResponse: Codable, Sendable {
    let schemaVersion: Int
    let photos: [PhotoCatalogPhoto]
}

struct PhotoCatalogPhoto: Codable, Sendable {
    let source: String
    let photoID: String
    let photoTitle: String
    let photoURL: String
    let thumbnailURL: String?
    let placeName: String
    let address: String?
    let sourceRegionCode: String?
    let shootingMonth: String?
    let latitude: Double?
    let longitude: Double?
    let regionCode: Int?
    let locationConfirmed: Bool

    /// 출처가 다른 사진의 ID 충돌을 막습니다. 원본 photoID는 응답에 그대로 보존합니다.
    var id: String { "\(source):\(photoID)" }

    var destination: PhotoDestination {
        PhotoDestination(
            id: id,
            name: placeName,
            photoURL: photoURL,
            detailDescription: photoTitle,
            regionCode: locationConfirmed ? regionCode : nil,
            address: address,
            // 미검증 좌표는 응답에 남기되 길찾기에 사용할 모델에는 전달하지 않습니다.
            latitude: locationConfirmed ? latitude : nil,
            longitude: locationConfirmed ? longitude : nil
        )
    }
}
