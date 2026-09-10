//
//  PhotoDestinationServiceFactory.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/10/26.
//

import Foundation

/// 1차 출시는 번들 카탈로그를 사용합니다. 서버 연결 시 기본 Client만 교체합니다.
enum PhotoDestinationServiceFactory {
    static func make(bundle: Bundle = .main) -> any PhotoDestinationService {
#if DEBUG
        switch source {
        case "tourAPI":
            return TourAPIPhotoDestinationService(configuration: .current)
        case "empty":
            return CatalogPhotoDestinationService(client: DebugPhotoCatalogClient(bundle: bundle, scenario: .empty))
        case "failure":
            return CatalogPhotoDestinationService(client: DebugPhotoCatalogClient(bundle: bundle, scenario: .failure))
        case "slow":
            return CatalogPhotoDestinationService(client: DebugPhotoCatalogClient(bundle: bundle, delay: .seconds(2)))
        default: break
        }
#endif
        return CatalogPhotoDestinationService(client: BundledPhotoCatalogClient(bundle: bundle))
    }

    static var sourceNotice: String? {
#if DEBUG
        switch source {
        case "tourAPI": return "TourAPI 테스트 · 위치 정보 미연결"
        case "empty", "failure", "slow": return "Debug · 카탈로그 응답 테스트"
        default: break
        }
#endif
        return "포항 관광사진 · 설정 반경과 무관하게 제공됩니다"
    }

#if DEBUG
    private static var source: String {
        ProcessInfo.processInfo.environment["PICSEL_PHOTO_SOURCE"] ?? "pohang"
    }
#endif
}
