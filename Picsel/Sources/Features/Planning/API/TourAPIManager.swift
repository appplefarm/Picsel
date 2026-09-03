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
        &numOfRows=10\
        &pageNo=1\
        &MobileOS=IOS\
        &MobileApp=Picsel\
        &areaCode=\(areaCode)\
        &sigunguCode=\(sigunguCode)\
        &arrange=A\
        &_type=json
        """
        
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decodedData = try JSONDecoder().decode(TourRoot.self, from: data)
        
        guard let items = decodedData.response.body.items.item else { return [] }
        
        return items.map { item in
            PlaceDTO(
                id: item.contentid,
                name: item.title,
                address: item.addr1 ?? "주소 미상",
                latitude: Double(item.mapy ?? "") ?? 0.0,
                longitude: Double(item.mapx ?? "") ?? 0.0,
                photoURL: (item.firstimage ?? "").replacingOccurrences(of: "http://", with: "https://"),
                detailDescription: nil,
                regionCode: nil
            )
        }
    }
}
