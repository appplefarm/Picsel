//
//  RegionCode.swift
//  Picsel
//

import Foundation

struct RegionCode: Codable, Identifiable {
    let id = UUID()
    let areaCd: String
    let areaNm: String
    let sigunguCd: String
    let sigunguNm: String
    
    enum CodingKeys: String, CodingKey {
        case areaCd, areaNm, sigunguCd, sigunguNm
    }
}

final class RegionCodeManager {
    static let shared = RegionCodeManager()
    
    var regions: [RegionCode] = []
    
    private init() {
        loadRegions()
    }
    
    private func loadRegions() {
        guard let url = Bundle.main.url(forResource: "RegionCodes", withExtension: "json") else {
            print("RegionCodes.json 파일을 찾을 수 없습니다.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([RegionCode].self, from: data)
            self.regions = decoded
        } catch {
            print("RegionCodes.json 파싱 에러: \(error.localizedDescription)")
        }
    }
    
    // 시도 코드로 필터링 예시
    func getSigunguList(for areaCode: String) -> [RegionCode] {
        return regions.filter { $0.areaCd == areaCode }
    }
    
    // 이름으로 검색 예시 (ex: "포항시 남구")
    func findRegion(by name: String) -> RegionCode? {
        var bestMatch: RegionCode? = nil
        var maxScore = 0
        
        for region in regions {
            var score = 0
            
            // 1. 도/광역시 이름이 포함되면 높은 점수 (예: "서울", "대구", "경상북도")
            // 단, API의 지역명("서울")이 유저 입력("서울특별시")에 포함되는지 확인
            if name.contains(region.areaNm) { 
                score += 10 
            }
            
            // 2. 시군구 이름이 포함되면 추가 점수
            if name.contains(region.sigunguNm) {
                // "남구", "동구" 등 흔한 구 이름은 자체 점수를 낮게 줌 (대구 남구 vs 포항시 남구 충돌 방지)
                if region.sigunguNm.count <= 2 && region.sigunguNm.hasSuffix("구") {
                    score += 1 
                } else {
                    score += 5 // "포항시", "강남구" 등은 높은 점수
                }
            }
            
            if score > maxScore {
                maxScore = score
                bestMatch = region
            }
        }
        
        return bestMatch
    }
}
