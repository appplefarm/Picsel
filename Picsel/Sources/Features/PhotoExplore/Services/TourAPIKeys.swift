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

    /// 인증키를 **퍼센트 인코딩된 그대로** 돌려줍니다.
    ///
    /// 공공데이터포털이 주는 키가 이미 인코딩된 형태입니다.
    /// (`.../BmG%2Fhzg...%3D%3D`) xcconfig에도 그 상태로 들어 있습니다.
    ///
    /// 이 값을 절대 풀어서 쓰면 안 됩니다. 두 가지가 동시에 어긋납니다.
    ///
    /// - `--data-urlencode`나 `URLComponents.queryItems`에 넣으면 `%`가 다시 인코딩돼
    ///   `%252F`가 됩니다. → SERVICE_KEY_IS_NOT_REGISTERED_ERROR
    /// - 반대로 풀어서 넣으면 `%2B`가 `+`가 되는데, `URLComponents`는 `+`를 쿼리에서
    ///   합법적인 문자로 보고 그대로 통과시킵니다. 서버는 `+`를 **공백**으로 읽습니다.
    ///   → 키가 망가져 403
    ///
    /// 그래서 인코딩된 값을 그대로 들고, `percentEncodedQuery`에 직접 붙입니다.
    /// (TourAPIRequest 참고)
    static func percentEncodedValue(for key: TourAPIKey) -> String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: key.infoPlistKey) as? String

        guard let raw,
              !raw.isEmpty,
              // xcconfig 치환이 안 되면 "$(TOUR_API_...)" 가 그대로 들어옵니다.
              !raw.contains("$(") else { return nil }

        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
