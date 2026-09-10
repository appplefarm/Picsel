//
//  TourAPIManager.swift
//  Picsel
//

import Foundation

final class TourAPIManager {
    static let shared = TourAPIManager()
    private init() {}
    
    private var serviceKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "TOUR_API_SERVICE_KEY_ENTRY") as? String else {
            fatalError("TOUR_API_SERVICE_KEY_ENTRY를 찾을 수 없음")
        }
        return key
    }
    
    // 국문 관광정보 API (지역기반 관광정보 조회)
    private let baseURL = "https://apis.data.go.kr/B551011/KorService2/areaBasedList2"
    
    func fetchRecommendedPlaces(areaCode: String, sigunguCode: String) async throws -> [PlaceDTO] {
        let urlString = """
        \(baseURL)\
        ?serviceKey=\(serviceKey)\
        &numOfRows=100\
        &pageNo=1\
        &MobileOS=IOS\
        &MobileApp=Picsel\
        &areaCode=\(areaCode)\
        &sigunguCode=\(sigunguCode)\
        &contentTypeId=12\
        &arrange=A\
        &_type=json
        """
        
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decodedData = try JSONDecoder().decode(TourRoot.self, from: data)
        
        guard let items = decodedData.response.body.items.item else { return [] }

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
