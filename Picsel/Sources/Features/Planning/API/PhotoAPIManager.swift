//
//  PhotoAPIManager.swift
//  Picsel
//
//  Created by 김나영 on 9/1/26.
//


import Foundation

final class PhotoAPIManager {
    static let shared = PhotoAPIManager()
    private init() {}
    
    private var serviceKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "TOUR_API_SERVICE_KEY_ENTRY") as? String else {
            fatalError("TOUR_API_SERVICE_KEY_ENTRY를 찾을 수 없음")
        }
        return key
    }
    private let baseURL = "https://apis.data.go.kr/B551011/PhotoGalleryService1/gallerySearchList1"
    
    func fetchRecommendedPhotos(keyword: String) async throws -> [PlaceDTO] {
        guard let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        
        let urlString = """
        \(baseURL)\
        ?serviceKey=\(serviceKey)\
        &numOfRows=10\
        &pageNo=1\
        &MobileOS=IOS\
        &MobileApp=Picsel\
        &arrange=B\
        &keyword=\(encodedKeyword)\
        &_type=json
        """
        
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decodedData = try JSONDecoder().decode(TourPhotoRoot.self, from: data)
        
        guard let items = decodedData.response.body.items.item else { return [] }
        
        // API 응답 데이터를 우리가 만든 PlaceDTO로 변환
        return items.map { item in
            PlaceDTO(
                id: item.galContentId,
                name: item.galTitle,
                address: item.galPhotographyLocation ?? "주소 미상",
                latitude: 0.0,  // 주의: 사진 API에 좌표 정보가 없음
                longitude: 0.0, // 주의: 사진 API에 좌표 정보가 없음
                photoURL: item.galWebImageUrl,
                detailDescription: nil,
                regionCode: nil
            )
        }
    }
}
