//
//  BundledPhotoCatalogClient.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/10/26.
//

import Foundation

#if DEBUG
/// 실제 서버나 API 키 없이 같은 비동기 응답을 시험합니다. 이미지 URL 요청은 별도입니다.
struct BundledPhotoCatalogClient: PhotoCatalogClient {
    enum Scenario: Sendable {
        case success, empty, failure
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
            guard let url = bundle.url(forResource: "pohang_photo_catalog", withExtension: "json") else {
                throw MockError.missingFixture
            }
            let data = try Data(contentsOf: url)
            let response = try JSONDecoder().decode(PhotoCatalogResponse.self, from: data)
            try Task.checkCancellation()
            return response
        }
    }

    enum MockError: LocalizedError {
        case missingFixture

        var errorDescription: String? { "앱 번들에서 포항 목업 JSON을 찾지 못했어요." }
    }
}
#endif
