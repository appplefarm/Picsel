//
//  TourAPIEnvelope.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import Foundation

/// 관광공사 API의 공통 응답 껍데기입니다.
///
/// 수상작(PhokoAwrdService)과 관광사진(PhotoGalleryService1)이 같은 모양을 씁니다.
/// 안쪽 `item`만 API마다 달라서 제네릭으로 둡니다.
///
/// ```json
/// {"response":{"header":{"resultCode":"0000","resultMsg":"OK"},
///              "body":{"items":{"item":[...]},"numOfRows":100,"pageNo":1,"totalCount":95}}}
/// ```
nonisolated struct TourAPIEnvelope<Item: Decodable & Sendable>: Decodable, Sendable {

    let response: Response

    struct Response: Decodable, Sendable {
        let header: Header
        let body: Body
    }

    struct Header: Decodable, Sendable {
        let resultCode: String
        let resultMessage: String

        enum CodingKeys: String, CodingKey {
            case resultCode
            case resultMessage = "resultMsg"
        }
    }

    struct Body: Decodable, Sendable {
        let items: [Item]
        let totalCount: Int
        let pageNo: Int
        let numOfRows: Int

        enum CodingKeys: String, CodingKey {
            case items, totalCount, pageNo, numOfRows
        }

        private struct ItemsBox: Decodable {
            let item: [Item]
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // 결과가 없으면 items가 객체가 아니라 빈 문자열("")로 오는 경우가 있습니다.
            // 그대로 디코딩하면 타입 오류로 터지므로 빈 배열로 받습니다.
            items = (try? container.decode(ItemsBox.self, forKey: .items))?.item ?? []

            totalCount = (try? container.decode(Int.self, forKey: .totalCount)) ?? items.count
            pageNo = (try? container.decode(Int.self, forKey: .pageNo)) ?? 1
            numOfRows = (try? container.decode(Int.self, forKey: .numOfRows)) ?? items.count
        }
    }
}

/// 관광공사 API 호출에서 나는 오류입니다.
nonisolated enum TourAPIError: LocalizedError {
    case missingServiceKey(TourAPIKey)
    case invalidRequest
    case invalidHTTPResponse(statusCode: Int)
    case server(code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .missingServiceKey(let key):
            "\(key.infoPlistKey)가 없어요. Secrets.xcconfig를 확인해주세요."
        case .invalidRequest:
            "관광공사 API 요청 주소를 만들지 못했어요."
        case .invalidHTTPResponse(let statusCode):
            "관광공사 서버가 \(statusCode)로 응답했어요."
        case let .server(code, message):
            "관광공사 API 오류 \(code): \(message)"
        }
    }
}

/// 관광공사 API에 한 페이지를 요청합니다.
///
/// 두 API가 호스트·공통 파라미터·오류 처리 방식을 공유해서 여기로 모읍니다.
nonisolated struct TourAPIRequest: Sendable {

    private static let host = "apis.data.go.kr"
    private static let mobileApp = "Picsel"

    let path: String
    let key: TourAPIKey
    let session: URLSession

    init(path: String, key: TourAPIKey, session: URLSession = .shared) {
        self.path = path
        self.key = key
        self.session = session
    }

    /// - Parameter extraQueryItems: API마다 다른 파라미터 (arrange 등)
    func fetch<Item: Decodable & Sendable>(
        pageNo: Int,
        numOfRows: Int,
        extraQueryItems: [URLQueryItem] = [],
        itemType: Item.Type = Item.self
    ) async throws -> TourAPIEnvelope<Item>.Body {

        guard let serviceKey = TourAPIKeys.value(for: key) else {
            throw TourAPIError.missingServiceKey(key)
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = path
        components.queryItems = [
            // 이미 풀어 둔 키를 넣고, 인코딩은 URLComponents에 한 번만 맡깁니다.
            URLQueryItem(name: "serviceKey", value: serviceKey),
            URLQueryItem(name: "MobileOS", value: "IOS"),
            URLQueryItem(name: "MobileApp", value: Self.mobileApp),
            URLQueryItem(name: "_type", value: "json"),
            URLQueryItem(name: "pageNo", value: String(pageNo)),
            URLQueryItem(name: "numOfRows", value: String(numOfRows))
        ] + extraQueryItems

        guard let url = components.url else { throw TourAPIError.invalidRequest }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TourAPIError.invalidHTTPResponse(statusCode: -1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TourAPIError.invalidHTTPResponse(statusCode: httpResponse.statusCode)
        }

        let envelope = try JSONDecoder().decode(TourAPIEnvelope<Item>.self, from: data)
        let header = envelope.response.header

        // HTTP는 200인데 본문에 오류가 담겨 오는 API라 여기서 한 번 더 봅니다.
        guard header.resultCode == "0000" else {
            throw TourAPIError.server(
                code: header.resultCode,
                message: header.resultMessage
            )
        }

        return envelope.response.body
    }
}
