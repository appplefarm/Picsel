//
//  PhotoDestinationServiceFactory.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/10/26.
//

import Foundation

/// 앱의 데이터 공급처 선택은 이곳에서만 합니다. Release는 기존 TourAPI를 유지합니다.
enum PhotoDestinationServiceFactory {
    static func make() -> any PhotoDestinationService {
#if DEBUG
        switch source {
        case "tourAPI": break
        case "empty":
            return CatalogPhotoDestinationService(client: BundledPhotoCatalogClient(scenario: .empty))
        case "failure":
            return CatalogPhotoDestinationService(client: BundledPhotoCatalogClient(scenario: .failure))
        default:
            return CatalogPhotoDestinationService(client: BundledPhotoCatalogClient())
        }
#endif
        return TourAPIPhotoDestinationService(configuration: .current)
    }

    static var sourceNotice: String? {
#if DEBUG
        if source != "tourAPI" {
            return "포항 목업 · 위치·반경 필터 미적용"
        }
#endif
        return nil
    }

#if DEBUG
    private static var source: String {
        ProcessInfo.processInfo.environment["PICSEL_PHOTO_SOURCE"] ?? "pohang"
    }
#endif
}
