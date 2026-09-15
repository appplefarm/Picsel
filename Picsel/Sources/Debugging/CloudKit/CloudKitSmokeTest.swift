//
//  CloudKitSmokeTest.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

#if DEBUG
import Foundation

/// 좌표 카탈로그가 제대로 내려오는지 확인하는 임시 점검입니다.
///
/// PhotoCoordinateCatalogStore를 그대로 쓰므로, 캐시·번들 대체까지 함께 확인됩니다.
/// 실제 화면이 이 값을 쓰기 시작하면 이 파일은 지웁니다.
enum CloudKitSmokeTest {

    static func run() async {
        print("──────── 좌표 카탈로그 점검 ────────")

        let started = ContinuousClock.now
        let catalog = await PhotoCoordinateCatalogStore.shared.catalog()
        let elapsed = ContinuousClock.now - started

        guard !catalog.isEmpty else {
            print("❌ 좌표를 하나도 받지 못했습니다.")
            print("   CloudKit·캐시·번들 복사본이 모두 실패했습니다.")
            print("   콘솔에서 PhotoCatalog 카테고리 로그를 확인하세요.")
            print("────────────────────────────────────")
            return
        }

        print("✅ \(catalog.photos.count)건 (\(elapsed))")

        for source in PhotoAPISource.allCases {
            print("   \(source.rawValue): \(catalog.photoIDs(of: source).count)건")
        }

        if let first = catalog.photos.first {
            print("   예시: \(first.placeName) "
                  + "(\(first.latitude), \(first.longitude)) "
                  + "지역 \(first.regionCode)")

            // 사진 ID로 되찾아지는지 확인합니다. 여기가 깨지면 API 응답과 못 잇습니다.
            let found = catalog.coordinate(
                forPhotoID: first.photoID,
                source: first.source
            ) != nil
            print(found ? "✅ ID 조회 정상" : "❌ ID 조회 실패")
        }

        // 앱 경계 데이터와 맞물리는지 봅니다. 0이면 지도에 아무것도 안 뜹니다.
        let regionCodes = Set(catalog.photos.map(\.regionCode))
        let matched = PixelRegionLocator.allRegions.filter {
            $0.containsAnyRegion(in: regionCodes)
        }
        print("✅ 경계 매칭: 픽셀 \(matched.count)곳 / 지역코드 \(regionCodes.count)종")

        print("────────────────────────────────────")
    }
}
#endif
