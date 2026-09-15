//
//  TourAPIKeys.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import Foundation

/// 관광공사 API 인증키를 꺼내 옵니다.
///
/// 키는 소스에 두지 않고 `Configs/Secrets.xcconfig` → Info.plist로 주입합니다.
nonisolated enum TourAPIKey: Sendable {
    /// 관광공모전 수상작 (PhokoAwrdService)
    case winners
    /// 관광사진 갤러리 (PhotoGalleryService1) · 국문 관광정보 (KorService2)
    case entry

    var infoPlistKey: String {
        switch self {
        case .winners: "TOUR_API_SERVICE_KEY_WINNERS"
        case .entry:   "TOUR_API_SERVICE_KEY_ENTRY"
        }
    }
}

nonisolated enum TourAPIKeys {

    /// 인증키를 **퍼센트 인코딩이 풀린 상태**로 돌려줍니다.
    ///
    /// xcconfig에 든 키는 이미 인코딩돼 있습니다. (`.../BmG%2Fhzg...%3D%3D`)
    /// 이걸 그대로 URLComponents에 넣으면 `%`가 다시 인코딩돼 `%252F`가 되고,
    /// 서버는 SERVICE_KEY_IS_NOT_REGISTERED_ERROR를 돌려줍니다.
    /// 그래서 먼저 풀어서 넘기고, 인코딩은 URLComponents에 한 번만 맡깁니다.
    static func value(for key: TourAPIKey) -> String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: key.infoPlistKey) as? String

        guard let raw,
              !raw.isEmpty,
              // xcconfig 치환이 안 되면 "$(TOUR_API_...)" 가 그대로 들어옵니다.
              !raw.contains("$(") else { return nil }

        return raw.removingPercentEncoding ?? raw
    }
}
