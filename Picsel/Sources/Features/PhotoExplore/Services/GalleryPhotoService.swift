//
//  GalleryPhotoService.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import Foundation
import OSLog

/// 관광사진 갤러리에서 우리가 좌표를 입힌 사진을 골라 옵니다.
///
/// 갤러리 전체는 6,000건이 넘는데 우리가 쓰는 건 426장입니다.
/// 그런데 이 API에는 ID로 거르는 파라미터가 없습니다.
/// (`galContentId`를 넣으면 INVALID_REQUEST_PARAMETER_ERROR가 납니다)
///
/// 그래서 페이지를 받아서 좌표가 있는 것만 걸러내고,
/// 화면에 필요한 만큼 모이면 멈춥니다.
/// 426 / 6,115 = 약 7%라, 1,000건짜리 한 페이지에 평균 70장쯤 들어 있습니다.
/// 보통 한 페이지면 충분합니다.
///
/// 페이지는 무작위로 고릅니다. 늘 1페이지만 받으면 사용자가 매번 같은 사진만 보게 됩니다.
///
/// 받은 값은 메모리에만 둡니다. 공모전 규정상 API 데이터는 저장하지 않습니다.
nonisolated struct GalleryPhotoService: Sendable {

    private static let path = "/B551011/PhotoGalleryService1/galleryList1"
    /// 한 페이지 1,000건이면 약 550KB · 0.6초입니다. 2,000까지 늘려도 받지만 셀룰러를 생각해 여기까지.
    private static let pageSize = 1_000
    /// 좌표가 드문 구간만 계속 걸리는 최악의 경우에도 이만큼만 받고 멈춥니다.
    private static let maximumPageAttempts = 3

    private let request: TourAPIRequest
    private let logger = Logger(subsystem: "com.applefarm.picsel", category: "GalleryPhoto")

    init(session: URLSession = .shared) {
        request = TourAPIRequest(path: Self.path, key: .entry, session: session)
    }

    /// - Parameters:
    ///   - wantedPhotoIDs: 좌표를 갖고 있는 사진 ID. 이 안에 드는 것만 남깁니다.
    ///   - minimumCount: 이만큼 모이면 더 받지 않습니다.
    func fetch(
        matching wantedPhotoIDs: Set<String>,
        minimumCount: Int
    ) async throws -> [RemotePhoto] {

        guard !wantedPhotoIDs.isEmpty, minimumCount > 0 else { return [] }

        // 몇 페이지짜리인지 알아야 무작위로 고를 수 있습니다.
        // 한 건만 요청하면 응답이 아주 작아서 부담이 없습니다.
        let totalCount = try await fetchTotalCount()
        let pageCount = max(1, Int((Double(totalCount) / Double(Self.pageSize)).rounded(.up)))

        var pagesToTry = Array(1...pageCount).shuffled()
        var collected: [String: RemotePhoto] = [:]
        var attempts = 0

        while collected.count < minimumCount,
              attempts < Self.maximumPageAttempts,
              let page = pagesToTry.popLast() {

            attempts += 1

            let body = try await request.fetch(
                pageNo: page,
                numOfRows: Self.pageSize,
                // A = 제목순. 순서가 고정이라 페이지를 골라도 겹치지 않습니다.
                extraQueryItems: [URLQueryItem(name: "arrange", value: "A")],
                itemType: GalleryPhotoDTO.self
            )

            try Task.checkCancellation()

            for dto in body.items where wantedPhotoIDs.contains(dto.galContentID) {
                guard let photo = dto.remotePhoto else { continue }
                collected[photo.photoID] = photo
            }

            logger.info("갤러리 \(page)/\(pageCount)페이지 → 누적 \(collected.count)장")
        }

        return Array(collected.values)
    }

    /// 전체가 몇 건인지만 확인합니다.
    private func fetchTotalCount() async throws -> Int {
        let body = try await request.fetch(
            pageNo: 1,
            numOfRows: 1,
            extraQueryItems: [URLQueryItem(name: "arrange", value: "A")],
            itemType: GalleryPhotoDTO.self
        )
        return body.totalCount
    }
}

/// 관광사진 API 응답 한 건입니다. 네트워크 계층 밖으로 나가지 않습니다.
nonisolated private struct GalleryPhotoDTO: Decodable, Sendable {

    let galContentID: String
    let title: String?
    let webImage: String?
    let thumbnailImage: String?
    let photographyLocation: String?

    enum CodingKeys: String, CodingKey {
        case galContentID = "galContentId"
        case title = "galTitle"
        case webImage = "galWebImageUrl"
        case thumbnailImage = "galWebThumbnailUrl"
        case photographyLocation = "galPhotographyLocation"
    }

    /// 이미지가 없는 항목은 화면에 띄울 수 없어 버립니다.
    var remotePhoto: RemotePhoto? {
        let image = webImage.flatMap(URL.init(string:))
        let thumbnail = thumbnailImage.flatMap(URL.init(string:))

        guard let imageURL = image ?? thumbnail else { return nil }

        return RemotePhoto(
            photoID: galContentID,
            source: .gallery,
            title: nonempty(title) ?? "이름 없는 관광사진",
            imageURL: imageURL,
            thumbnailURL: thumbnail,
            shootingLocation: nonempty(photographyLocation)
        )
    }

    private func nonempty(_ value: String?) -> String? {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return value
    }
}
