//
//  PhotoCoordinate.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import CoreLocation
import Foundation

/// 사진 한 장을 어느 API에서 가져와야 하는지입니다.
///
/// 514장이 두 API에서 오고, 사진 ID만으로는 구분되지 않아 따로 들고 다닙니다.
nonisolated enum PhotoAPISource: String, Codable, Sendable, CaseIterable {
    /// 관광공모전 수상작. PhokoAwrdService의 `contentId`와 사진 ID가 같습니다.
    case award
    /// 관광사진 갤러리. PhotoGalleryService1의 `galContentId`와 사진 ID가 같습니다.
    case gallery
}

/// 사진 한 장에 팀이 직접 입힌 위치 정보입니다.
///
/// 관광공사 API는 좌표를 주지 않습니다. 촬영지가 "강원특별자치도 정선군 남면, 민둥산"처럼
/// 글로만 오기 때문에, 지도에 찍으려면 좌표가 따로 필요합니다.
/// 그래서 팀이 514장에 위도·경도를 입혀 CloudKit public DB에 올려 두고 앱이 받아 씁니다.
///
/// 제목·이미지 주소 같은 API가 주는 값은 여기 담지 않습니다.
/// 그건 화면을 그릴 때마다 API에서 실시간으로 받아옵니다.
nonisolated struct PhotoCoordinate: Codable, Sendable, Identifiable {

    let photoID: String
    let source: PhotoAPISource
    /// 촬영지 글만으로는 알기 어려운 구체적인 장소입니다. "하멜등대"
    let placeName: String
    let address: String
    let latitude: Double
    let longitude: Double
    /// 번들 경계 데이터(sigungu_boundaries)의 코드와 같은 체계입니다. "47130"
    let regionCode: String

    /// 두 API의 ID가 겹칠 수 있어 출처를 함께 씁니다.
    var id: String { "\(source.rawValue):\(photoID)" }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// CloudKit에서 받은 좌표 데이터 한 벌입니다.
nonisolated struct PhotoCoordinateCatalog: Codable, Sendable {

    let schemaVersion: Int
    let photos: [PhotoCoordinate]

    /// 출처별로 사진 ID에서 바로 찾을 수 있게 미리 묶어 둡니다.
    /// API 응답 수백 건을 훑으며 매번 배열을 뒤지면 느립니다.
    private let index: [String: PhotoCoordinate]

    init(schemaVersion: Int, photos: [PhotoCoordinate]) {
        self.schemaVersion = schemaVersion
        self.photos = photos
        index = Dictionary(photos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
            photos: try container.decode([PhotoCoordinate].self, forKey: .photos)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(photos, forKey: .photos)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, photos
    }

    static let empty = PhotoCoordinateCatalog(schemaVersion: 0, photos: [])

    var isEmpty: Bool { photos.isEmpty }

    /// API 응답 한 건에 맞는 좌표를 찾습니다. 못 찾으면 그 사진은 지도에 띄우지 않습니다.
    func coordinate(forPhotoID photoID: String, source: PhotoAPISource) -> PhotoCoordinate? {
        index["\(source.rawValue):\(photoID)"]
    }

    /// 이 출처에서 우리가 쓸 사진 ID 목록입니다. API 응답을 거를 때 씁니다.
    func photoIDs(of source: PhotoAPISource) -> Set<String> {
        Set(photos.lazy.filter { $0.source == source }.map(\.photoID))
    }
}
