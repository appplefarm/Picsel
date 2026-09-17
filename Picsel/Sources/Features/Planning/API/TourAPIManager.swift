//
//  TourAPIManager.swift
//  Picsel
//

import Foundation

final class TourAPIManager {
    static let shared = TourAPIManager()
    private let session: URLSession
    private let serviceKey: String?

    init(session: URLSession = .shared, serviceKey: String? = nil) {
        self.session = session
        self.serviceKey = serviceKey
            ?? Bundle.main.object(forInfoDictionaryKey: "TOUR_API_SERVICE_KEY_ENTRY") as? String
    }
    
    // 국문 관광정보 API (지역기반 관광정보 조회)
    private let baseURL = "https://apis.data.go.kr/B551011/KorService2/areaBasedList2"
    
    func fetchRecommendedPlaces(areaCode: String, sigunguCode: String) async throws -> [PlaceDTO] {
        guard let serviceKey, !serviceKey.isEmpty, !serviceKey.contains("$(") else {
            throw RequestFailure.configuration
        }
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "serviceKey", value: serviceKey.removingPercentEncoding ?? serviceKey),
            URLQueryItem(name: "numOfRows", value: "100"),
            URLQueryItem(name: "pageNo", value: "1"),
            URLQueryItem(name: "MobileOS", value: "IOS"),
            URLQueryItem(name: "MobileApp", value: "Picsel"),
            URLQueryItem(name: "areaCode", value: areaCode),
            URLQueryItem(name: "sigunguCode", value: sigunguCode),
            URLQueryItem(name: "contentTypeId", value: "12"),
            URLQueryItem(name: "arrange", value: "A"),
            URLQueryItem(name: "_type", value: "json")
        ]
        // 서비스 키의 '+'가 공백으로 해석되지 않게 인코딩합니다.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw RequestFailure.configuration }
        let request = URLRequest(url: url, timeoutInterval: 20)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RequestFailure.server
        }
        
        let decodedData = try JSONDecoder().decode(TourRoot.self, from: data)
        
        guard decodedData.response.header.resultCode == "0000" else {
            throw RequestFailure.server
        }
        guard let body = decodedData.response.body else { throw RequestFailure.invalidResponse }
        guard body.totalCount > 0 else { return [] }
        guard let items = body.items?.item else { throw RequestFailure.invalidResponse }

        // 사진으로 목적지를 고르는 서비스라 대표 이미지가 없는 장소는 제외합니다.
        // 응답에서 걸러낸 뒤 랜덤으로 섞어서 필요한 개수만 뽑아냅니다.
        return items
            .compactMap { item -> PlaceDTO? in
                guard let photoURL = Self.secureImageURL(from: item.firstimage) else {
                    return nil
                }

                return PlaceDTO(
                    id: item.contentid,
                    name: item.title,
                    address: item.addr1 ?? "주소 미상",
                    latitude: Double(item.mapy ?? "") ?? 0.0,
                    longitude: Double(item.mapx ?? "") ?? 0.0,
                    photoURL: photoURL,
                    detailDescription: nil,
                    regionCode: nil
                )
            }
            .shuffled()
            .prefix(Self.recommendationCount)
            .map { $0 }
    }

    /// 추천 카드로 보여줄 장소 개수입니다.
    private static let recommendationCount = 10

    /// 관광공사 이미지가 http로 내려오면 App Transport Security에 막혀 로드되지 않습니다.
    /// 비어 있으면 사진이 없는 장소이므로 nil을 돌려줍니다.
    private static func secureImageURL(from value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value.replacingOccurrences(of: "http://", with: "https://")
    }
}
