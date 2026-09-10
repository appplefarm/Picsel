//
//  CatalogPhotoDestinationService.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/10/26.
//

import Foundation

/// 서버 응답을 기존 사진 탐색 모델로 바꾸는 어댑터. 화면은 공급처를 알 필요가 없습니다.
struct CatalogPhotoDestinationService: PhotoDestinationService {
    let client: any PhotoCatalogClient

    func fetchDestinations(limit: Int) async throws -> [PhotoDestination] {
        guard limit > 0 else { return [] }
        let response = try await client.fetchCatalog()
        try Task.checkCancellation()

        guard response.schemaVersion == 1 else { throw CatalogError.unsupportedSchema }

        var seenIDs = Set<String>()
        for photo in response.photos {
            guard !photo.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !photo.photoID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !photo.placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let url = URL(string: photo.photoURL),
                  url.scheme == "https", let host = url.host, !host.isEmpty,
                  seenIDs.insert(photo.id).inserted else {
                throw CatalogError.invalidPhoto
            }
        }

        // 확정할 수 없는 장소를 먼저 제외한 뒤 표시 개수를 제한합니다.
        // 거리 필터·랜덤 추천과 무관하게 서버 공급으로 바뀌어도 같은 검증을 적용합니다.
        return Array(response.photos.lazy
            .map(\.destination)
            .filter(\.canSelectAsDestination)
            .prefix(limit))
    }

    enum CatalogError: LocalizedError {
        case unsupportedSchema
        case invalidPhoto

        var errorDescription: String? {
            switch self {
            case .unsupportedSchema: "지원하지 않는 사진 목록 형식이에요."
            case .invalidPhoto: "사진 목록에 중복되거나 잘못된 정보가 있어요."
            }
        }
    }
}
