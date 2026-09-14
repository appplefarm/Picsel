//
//  TripRegionName.swift
//  Picsel
//
//  Created by kosoobin on 9/10/26.
//

import Foundation

/// 목적지 주소에서 기록 화면에 노출할 지역 이름을 뽑아냅니다.
/// "경상북도 포항시 북구 청하면 이가리" -> "포항"
///
/// TODO: 픽셀 코드(시군구 5자리) 매칭은 저장 단계에서 경계 데이터로 따로 처리합니다.
///       여기서는 화면에 보여줄 이름만 만듭니다.
enum TripRegionName {

    /// 시 자체가 광역 단위인 곳은 아래 구까지 내려가지 않고 그대로 씁니다.
    private static let metropolitanNames: [String: String] = [
        "서울특별시": "서울",
        "부산광역시": "부산",
        "대구광역시": "대구",
        "인천광역시": "인천",
        "광주광역시": "광주",
        "대전광역시": "대전",
        "울산광역시": "울산",
        "세종특별자치시": "세종"
    ]

    /// 주소를 못 읽었을 때 쓰는 값입니다. PicselMapRecord와 같은 문구를 씁니다.
    static let fallback = "여행 지역"

    /// 긴 접미사를 먼저 지워야 "특별자치도"가 "도"로 잘리지 않습니다.
    private static let suffixes = [
        "특별자치도", "특별자치시", "광역시", "특별시", "시", "군", "구", "도"
    ]

    static func make(from address: String?) -> String {
        guard let address else { return fallback }

        let components = address
            .split(separator: " ")
            .map(String.init)

        guard let province = components.first else { return fallback }

        if let metropolitan = metropolitanNames[province] {
            return metropolitan
        }

        // 도 단위 주소는 두 번째 토막이 시·군입니다. ("경상북도 포항시 ...")
        guard components.count >= 2 else { return trimmed(province) }
        return trimmed(components[1])
    }

    /// "포항시" -> "포항", "울릉군" -> "울릉", "종로구" -> "종로"
    private static func trimmed(_ name: String) -> String {
        for suffix in suffixes where name.hasSuffix(suffix) && name.count > suffix.count {
            return String(name.dropLast(suffix.count))
        }
        return name
    }
}
