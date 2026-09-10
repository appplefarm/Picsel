//
//  PhotoDestination.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import Foundation

/// 사진 탐색 중 사용하는 목적지 후보입니다.
///
/// TourAPI 사진 응답에는 주소와 좌표가 없으므로 공용 `PlaceDTO`와 분리합니다.
/// 서버가 위치 정보를 보강하면 `placeDTO`를 통해 공용 모델로 변환할 수 있습니다.
struct PhotoDestination: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let photoURL: String?
    let detailDescription: String?
    let regionCode: Int?

    let address: String?
    let latitude: Double?
    let longitude: Double?

    init(
        id: String,
        name: String,
        photoURL: String? = nil,
        detailDescription: String? = nil,
        regionCode: Int? = nil,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.photoURL = photoURL
        self.detailDescription = detailDescription
        self.regionCode = regionCode
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }

    init(placeDTO: PlaceDTO) {
        self.init(
            id: placeDTO.id,
            name: placeDTO.name,
            photoURL: placeDTO.photoURL,
            detailDescription: placeDTO.detailDescription,
            regionCode: placeDTO.regionCode,
            address: placeDTO.address,
            latitude: placeDTO.latitude,
            longitude: placeDTO.longitude
        )
    }

    /// 주소와 좌표가 서버에서 보강된 후보만 공용 장소 모델로 변환합니다.
    var placeDTO: PlaceDTO? {
        guard canSelectAsDestination, let address, let latitude, let longitude else { return nil }

        return PlaceDTO(
            id: id,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            photoURL: photoURL,
            detailDescription: detailDescription,
            regionCode: regionCode
        )
    }

    /// 미검증 좌표는 공급 계층에서 nil로 전달합니다. 사진 탐색과 경로 확정은 구분합니다.
    var canSelectAsDestination: Bool {
        guard let latitude, let longitude else { return false }
        return latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
