//
//  BundledPhotoCatalogClient.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/11/26.
//

import Foundation

/// 1차 출시용 장소 카탈로그입니다. 이미지 파일은 응답의 HTTPS URL에서 별도로 로드합니다.
struct BundledPhotoCatalogClient: PhotoCatalogClient {
    var bundle: Bundle = .main

    func fetchCatalog() async throws -> PhotoCatalogResponse {
        try Task.checkCancellation()
        guard let url = bundle.url(forResource: "pohang_photo_catalog", withExtension: "json") else {
            throw CatalogFileError.missingResource
        }

        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(PhotoCatalogResponse.self, from: data)
        try Task.checkCancellation()
        return response
    }

    enum CatalogFileError: LocalizedError {
        case missingResource

        var errorDescription: String? { "앱에 포함된 관광사진 목록을 찾을 수 없어요." }
    }
}
