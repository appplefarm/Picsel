//
//  AwardPhotoService.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import Foundation
import OSLog

/// 대한민국 관광공모전 수상작을 받아 옵니다.
///
/// 전체가 95건이라 한 번(numOfRows=100)이면 다 옵니다.
/// 그래도 다음 회차 수상작이 더해질 수 있어 totalCount를 보고 남으면 이어 받습니다.
///
/// 받은 값은 메모리에만 둡니다. 공모전 규정상 API 데이터는 저장하지 않습니다.
nonisolated struct AwardPhotoService: Sendable {

    private static let path = "/B551011/PhokoAwrdService/phokoAwrdList"
    private static let pageSize = 100
    /// 응답이 이상하게 커져도 무한히 돌지 않게 막아 둡니다.
    private static let maximumPages = 10

    private let request: TourAPIRequest
    private let logger = Logger(subsystem: "com.applefarm.picsel", category: "AwardPhoto")

    init(session: URLSession = .shared) {
        request = TourAPIRequest(path: Self.path, key: .winners, session: session)
    }

    /// 수상작 전체를 받아 옵니다.
    func fetchAll() async throws -> [RemotePhoto] {
        var photos: [RemotePhoto] = []
        var page = 1

        while page <= Self.maximumPages {
            let body = try await request.fetch(
                pageNo: page,
                numOfRows: Self.pageSize,
                // C = 수정일순. 최근에 손댄 수상작이 앞에 옵니다.
                extraQueryItems: [URLQueryItem(name: "arrange", value: "C")],
                itemType: AwardPhotoDTO.self
            )

            try Task.checkCancellation()
            photos.append(contentsOf: body.items.compactMap(\.remotePhoto))

            // 받은 수가 요청한 수보다 적으면 마지막 페이지입니다.
            guard body.items.count == Self.pageSize,
                  photos.count < body.totalCount else { break }

            page += 1
        }

        logger.info("수상작 \(photos.count)건 수신 (\(page)페이지)")
        return photos
    }
}

/// 수상작 API 응답 한 건입니다. 네트워크 계층 밖으로 나가지 않습니다.
nonisolated private struct AwardPhotoDTO: Decodable, Sendable {

    let contentID: String
    let koreanTitle: String?
    let englishTitle: String?
    let shootingLocation: String?
    let originalImage: String?
    let thumbnailImage: String?

    enum CodingKeys: String, CodingKey {
        case contentID = "contentId"
        case koreanTitle = "koTitle"
        case englishTitle = "enTitle"
        case shootingLocation = "koFilmst"
        case originalImage = "orgImage"
        case thumbnailImage = "thumbImage"
    }

    /// 이미지가 없는 항목은 화면에 띄울 수 없어 버립니다.
    var remotePhoto: RemotePhoto? {
        let original = originalImage.flatMap(URL.init(string:))
        let thumbnail = thumbnailImage.flatMap(URL.init(string:))

        guard let imageURL = original ?? thumbnail else { return nil }

        return RemotePhoto(
            photoID: contentID,
            source: .award,
            title: nonempty(koreanTitle) ?? nonempty(englishTitle) ?? "이름 없는 수상작",
            imageURL: imageURL,
            thumbnailURL: thumbnail,
            shootingLocation: nonempty(shootingLocation)
        )
    }

    private func nonempty(_ value: String?) -> String? {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return value
    }
}
