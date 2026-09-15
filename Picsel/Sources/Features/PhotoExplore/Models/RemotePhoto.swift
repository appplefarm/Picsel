//
//  RemotePhoto.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import Foundation

/// API가 방금 내려준 사진 한 장입니다.
///
/// 수상작 API와 관광사진 API는 필드 이름이 다르지만(`contentId`/`galContentId`,
/// `koTitle`/`galTitle`) 화면에 필요한 값은 같습니다. 그래서 여기로 모아 둡니다.
///
/// 이 값은 **디스크에 저장하지 않습니다.** 공모전 규정이 실시간 호출을 요구하므로
/// 화면을 그릴 때마다 새로 받고, 앱을 끄면 사라집니다.
/// 좌표는 여기 없습니다. PhotoCoordinate와 짝지어야 지도에 찍을 수 있습니다.
nonisolated struct RemotePhoto: Sendable, Identifiable {

    /// 수상작은 `contentId`, 관광사진은 `galContentId`입니다.
    /// 좌표 데이터의 photoID와 같은 값이라 이걸로 짝을 찾습니다.
    let photoID: String
    let source: PhotoAPISource
    let title: String
    let imageURL: URL
    let thumbnailURL: URL?
    /// API가 글로 주는 촬영지입니다. "강원특별자치도 정선군 남면, 민둥산"
    let shootingLocation: String?

    var id: String { "\(source.rawValue):\(photoID)" }

    /// 상세 확대에서도 선명하도록 원본을 우선합니다.
    var displayImageURL: URL { imageURL }
}
