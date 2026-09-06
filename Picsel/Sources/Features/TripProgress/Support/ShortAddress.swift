//
//  ShortAddress.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import Foundation

/// 관광정보 API의 전체 주소를 시안처럼 짧게 줄입니다.
/// "경상북도 포항시 북구 청하면 이가리 552" -> "경북 포항시 북구"
enum ShortAddress {

    /// 시안은 "도/광역시 + 시 + 구" 세 토막까지만 보여 줍니다.
    private static let componentLimit = 3

    private static let abbreviations: [String: String] = [
        "서울특별시": "서울",
        "부산광역시": "부산",
        "대구광역시": "대구",
        "인천광역시": "인천",
        "광주광역시": "광주",
        "대전광역시": "대전",
        "울산광역시": "울산",
        "세종특별자치시": "세종",
        "경기도": "경기",
        "강원도": "강원",
        "강원특별자치도": "강원",
        "충청북도": "충북",
        "충청남도": "충남",
        "전라북도": "전북",
        "전북특별자치도": "전북",
        "전라남도": "전남",
        "경상북도": "경북",
        "경상남도": "경남",
        "제주특별자치도": "제주"
    ]

    static func make(from address: String?) -> String? {
        guard let address, !address.isEmpty else { return nil }

        var components = address
            .split(separator: " ")
            .map(String.init)

        guard !components.isEmpty else { return nil }

        if let abbreviation = abbreviations[components[0]] {
            components[0] = abbreviation
        }

        return components.prefix(componentLimit).joined(separator: " ")
    }
}
