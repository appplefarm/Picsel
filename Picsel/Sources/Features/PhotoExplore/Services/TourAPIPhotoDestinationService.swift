//
//  TourAPIPhotoDestinationService.swift
//  Picsel
//

import Foundation

struct TourAPIPhotoConfiguration: Sendable {
    let serviceKey: String
    let mobileApp: String

    init(serviceKey: String, mobileApp: String = "Picsel") {
        self.serviceKey = serviceKey
        self.mobileApp = mobileApp
    }

    /// 키는 소스에 저장하지 않고 Xcode Scheme 환경변수 또는 Info.plist로 주입합니다.
    static var current: TourAPIPhotoConfiguration {
        let environmentKey = ProcessInfo.processInfo.environment["TOUR_API_SERVICE_KEY"]
        let bundleKey = Bundle.main.object(forInfoDictionaryKey: "TOUR_API_SERVICE_KEY") as? String
        let rawKey = environmentKey ?? bundleKey ?? ""
        let serviceKey = rawKey.contains("$(") ? "" : rawKey

        return TourAPIPhotoConfiguration(serviceKey: serviceKey)
    }
}

enum TourAPIPhotoDestinationServiceError: LocalizedError {
    case missingServiceKey
    case invalidRequest
    case invalidHTTPResponse
    case server(code: String, message: String)
    case insufficientPlaces(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .missingServiceKey:
            "TourAPI serviceKey가 필요합니다."
        case .invalidRequest:
            "관광사진 요청 URL을 만들 수 없습니다."
        case .invalidHTTPResponse:
            "관광사진 서버 응답을 확인할 수 없습니다."
        case let .server(code, message):
            "TourAPI 오류 \(code): \(message)"
        case let .insufficientPlaces(expected, actual):
            "\(expected)개의 장소가 필요하지만 \(actual)개만 해석했습니다."
        }
    }
}

/// 관광사진 API 응답을 사진 탐색용 목적지 후보로 변환합니다.
/// 주소와 좌표는 추후 서버 래퍼가 보강하며, 현재 테스트에서는 비워 둡니다.
/// 랜덤 선택은 추후 `records`의 순서를 구성하는 지점에 추가합니다.
struct TourAPIPhotoDestinationService: PhotoDestinationService {
    private let configuration: TourAPIPhotoConfiguration
    private let session: URLSession

    init(
        configuration: TourAPIPhotoConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func fetchDestinations(limit: Int) async throws -> [PhotoDestination] {
        guard !configuration.serviceKey.isEmpty else {
            throw TourAPIPhotoDestinationServiceError.missingServiceKey
        }

        let requestedCount = min(max(limit, 1), 100)
        let records = try await fetchPhotoRecords(limit: requestedCount)
        let destinations = records.map { record in
            PhotoDestination(
                id: record.id,
                name: record.title,
                photoURL: record.displayImageURL?.absoluteString,
                detailDescription: record.shootingLocation,
                regionCode: record.regionCode.flatMap(Int.init)
            )
        }

        guard destinations.count == requestedCount else {
            throw TourAPIPhotoDestinationServiceError.insufficientPlaces(
                expected: requestedCount,
                actual: destinations.count
            )
        }

        return destinations
    }

    private func fetchPhotoRecords(limit: Int) async throws -> [TourPhotoRecord] {
        guard let url = makeRequestURL(limit: limit) else {
            throw TourAPIPhotoDestinationServiceError.invalidRequest
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TourAPIPhotoDestinationServiceError.invalidHTTPResponse
        }

        let envelope = try JSONDecoder().decode(TourPhotoAPIEnvelope.self, from: data)
        let header = envelope.response.header

        guard header.resultCode == "0000" else {
            throw TourAPIPhotoDestinationServiceError.server(
                code: header.resultCode,
                message: header.resultMessage
            )
        }

        return envelope.response.body.items?.item
            .compactMap(\.record)
            .prefix(limit)
            .map { $0 } ?? []
    }

    private func makeRequestURL(limit: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "apis.data.go.kr"
        components.path = "/B551011/PhokoAwrdService/phokoAwrdList"
        components.queryItems = [
            URLQueryItem(
                name: "serviceKey",
                value: configuration.serviceKey.removingPercentEncoding
                    ?? configuration.serviceKey
            ),
            URLQueryItem(name: "MobileOS", value: "IOS"),
            URLQueryItem(name: "MobileApp", value: configuration.mobileApp),
            URLQueryItem(name: "_type", value: "json"),
            URLQueryItem(name: "arrange", value: "C"),
            URLQueryItem(name: "pageNo", value: "1"),
            URLQueryItem(name: "numOfRows", value: String(limit))
        ]
        return components.url
    }
}

/// 네트워크 계층 내부에서만 사용하는 관광사진 레코드입니다.
private struct TourPhotoRecord: Sendable {
    let id: String
    let title: String
    let shootingLocation: String
    let originalImageURL: URL?
    let thumbnailImageURL: URL?
    let regionCode: String?

    /// 상세 확대에서도 선명하도록 원본을 우선하고, 없을 때만 썸네일을 사용합니다.
    var displayImageURL: URL? {
        originalImageURL ?? thumbnailImageURL
    }
}

private struct TourPhotoAPIEnvelope: Decodable {
    let response: APIResponse

    struct APIResponse: Decodable {
        let header: Header
        let body: Body
    }

    struct Header: Decodable {
        let resultCode: String
        let resultMessage: String

        enum CodingKeys: String, CodingKey {
            case resultCode
            case resultMessage = "resultMsg"
        }
    }

    struct Body: Decodable {
        let items: Items?
    }

    struct Items: Decodable {
        let item: [TourPhotoDTO]
    }
}

private struct TourPhotoDTO: Decodable {
    let contentID: String
    let koreanTitle: String?
    let englishTitle: String?
    let shootingLocation: String?
    let originalImage: String?
    let thumbnailImage: String?
    let regionCode: String?

    enum CodingKeys: String, CodingKey {
        case contentID = "contentId"
        case koreanTitle = "koTitle"
        case englishTitle = "enTitle"
        case shootingLocation = "koFilmst"
        case originalImage = "orgImage"
        case thumbnailImage = "thumbImage"
        case regionCode = "lDongRegnCd"
    }

    var record: TourPhotoRecord? {
        let originalURL = originalImage.flatMap(URL.init(string:))
        let thumbnailURL = thumbnailImage.flatMap(URL.init(string:))

        guard originalURL != nil || thumbnailURL != nil else { return nil }

        return TourPhotoRecord(
            id: contentID,
            title: nonempty(koreanTitle) ?? nonempty(englishTitle) ?? "이름 없는 관광사진",
            shootingLocation: nonempty(shootingLocation) ?? "촬영 위치 정보 없음",
            originalImageURL: originalURL,
            thumbnailImageURL: thumbnailURL,
            regionCode: nonempty(regionCode)
        )
    }

    private func nonempty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}
