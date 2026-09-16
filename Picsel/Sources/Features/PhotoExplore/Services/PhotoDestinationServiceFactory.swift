//
//  PhotoDestinationServiceFactory.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/10/26.
//

import CoreLocation
import Foundation

/// 앱의 데이터 공급처 선택은 이곳에서만 합니다.
///
/// 기본은 실제 경로입니다. 관광공사 API에서 사진을 실시간으로 받고
/// CloudKit의 좌표와 짝지어 목적지 후보를 만듭니다.
///
/// 목업은 `PICSEL_PHOTO_SOURCE` 환경변수로만 켭니다.
/// (Xcode Scheme → Run → Arguments → Environment Variables)
enum PhotoDestinationServiceFactory {
    static func make(
        originLocation: CLLocation? = nil,
        selectedRadiusMeters: CLLocationDistance = PhotoRecommendationPolicy.minimumRadiusMeters
    ) -> any PhotoDestinationService {
#if DEBUG
        switch source {
        case "empty":
            return CatalogPhotoDestinationService(client: BundledPhotoCatalogClient(scenario: .empty))
        case "failure":
            return CatalogPhotoDestinationService(client: BundledPhotoCatalogClient(scenario: .failure))
        case "pohang":
            return CatalogPhotoDestinationService(client: BundledPhotoCatalogClient())
        default:
            break
        }
#endif
        return LivePhotoDestinationService(
            originLocation: originLocation,
            selectedRadiusMeters: selectedRadiusMeters
        )
    }

    static var sourceNotice: String? {
#if DEBUG
        if source != "live" {
            return "목업 데이터 · 위치·반경 필터 미적용"
        }
#endif
        return nil
    }

#if DEBUG
    /// 기본값은 실제 경로입니다. 목업을 보려면 "pohang" / "empty" / "failure"를 넣으세요.
    private static var source: String {
        ProcessInfo.processInfo.environment["PICSEL_PHOTO_SOURCE"] ?? "live"
    }
#endif
}
