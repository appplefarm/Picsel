//
//  ContentSources.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/11/26.
//

import Foundation

/// 출처 안내에만 사용하는 값입니다. 공용 모델이나 사진별 이용 허락 여부를 대체하지 않습니다.
enum ContentSources {
    static let tourismCredit = "사진 제공: 한국관광공사"
    static let boundaryCredit = "경계: 국토교통부·브이월드 / Picsel 가공"

    static let tourism = URL(string: "https://api.visitkorea.or.kr/")!
    static let tourismTerms = URL(string: "https://api.visitkorea.or.kr/#/agrAgreement")!
    static let tourismCopyright = URL(string: "https://knto.or.kr/helpdeskCopyrightguide")!
    static let photoAPI = URL(string: "https://www.data.go.kr/data/15101914/openapi.do")!
    static let boundaries = URL(string: "https://www.vworld.kr/dtmk/dtmk_ntads_s002.do?svcCde=NA&dsId=21")!
    static let googleTerms = URL(string: "https://cloud.google.com/maps-platform/terms")!
    static let googleAttribution = URL(string: "https://developers.google.com/maps/documentation/ios-sdk/policies")!
    static let naverGuide = URL(string: "https://navermaps.github.io/ios-map-sdk/guide-ko/4-1.html")!

    /// 확인되는 이미지 호스트에만 제공처를 표시합니다. 사용자 촬영 사진에는 붙이지 않습니다.
    static func isTourismPhoto(_ urlString: String?) -> Bool {
        guard let urlString, let url = URL(string: urlString), url.scheme == "https" else { return false }
        return url.host?.lowercased() == "tong.visitkorea.or.kr"
    }
}
