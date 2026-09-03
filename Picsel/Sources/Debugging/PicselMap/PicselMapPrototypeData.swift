//
//  PicselMapPrototypeData.swift
//  Picsel
//
//  Created by JonghyeonLee on 9/1/26.
//

#if DEBUG
import Foundation

enum PicselMapPrototypeData {
    /// 그룹화된 행정구역 경계와 선택 상호작용을 검증하기 위한 데이터입니다.
    static let loadResult: Result<[AdministrativeRegion], Error> = Result {
        let regions = try BundledGeoJSONRegionRepository().loadRegions()

        guard regions.count == 161 else {
            throw PreviewDataError.unexpectedRegionCount(regions.count)
        }

        return regions
    }

    static var regions: [AdministrativeRegion] {
        (try? loadResult.get()) ?? []
    }

    static var unlockedRegionCodes: Set<String> {
        ["11110", "26350", "50110"]
    }

    private enum PreviewDataError: LocalizedError {
        case unexpectedRegionCount(Int)

        var errorDescription: String? {
            switch self {
            case .unexpectedRegionCount(let count):
                "161개 선택 지역이 필요하지만 \(count)개를 불러왔어요."
            }
        }
    }
}
#endif
