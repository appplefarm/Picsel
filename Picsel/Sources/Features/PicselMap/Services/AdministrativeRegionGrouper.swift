//
//  AdministrativeRegionGrouper.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/3/26.
//

import Foundation

/// 시군구 경계 데이터는 보존하면서 사용자가 선택하는 지역 단위를 합칩니다.
enum AdministrativeRegionGrouper {
    nonisolated private struct Group: Hashable {
        let code: String
        let name: String
        let parentCode: String?
    }

    nonisolated private static let metropolitanNames: [String: String] = [
        "11": "서울특별시",
        "26": "부산광역시",
        "27": "대구광역시",
        "28": "인천광역시",
        "29": "광주광역시",
        "30": "대전광역시",
        "31": "울산광역시"
    ]

    /// 2026년 원본에서는 광주 5개 구가 전남광주(12)에 속합니다.
    /// 지도에서는 기존 광주 타일을 유지하되 전남의 시·군까지 합치지 않습니다.
    nonisolated private static let gwangjuDistrictCodes: Set<String> = [
        "12210", "12240", "12270", "12300", "12330"
    ]

    nonisolated static func group(
        _ regions: [AdministrativeRegion]
    ) -> [AdministrativeRegion] {
        Dictionary(grouping: regions, by: group(for:))
            .map { group, members in
                AdministrativeRegion(
                    code: group.code,
                    name: group.name,
                    parentCode: group.parentCode,
                    constituentCodes: Set(
                        members.flatMap(\.constituentCodes)
                    ),
                    polygons: members.flatMap(\.polygons)
                )
            }
            .sorted { $0.code < $1.code }
    }

    nonisolated private static func group(
        for region: AdministrativeRegion
    ) -> Group {
        if region.parentCode == "12", gwangjuDistrictCodes.contains(region.code) {
            return Group(code: "29", name: "광주", parentCode: "12")
        }

        if let parentCode = region.parentCode,
           let metropolitanName = metropolitanNames[parentCode] {
            return Group(
                code: parentCode,
                name: metropolitanName,
                parentCode: nil
            )
        }

        if let cityName = cityName(from: region.name) {
            return Group(
                code: String(region.code.prefix(4)),
                name: cityName,
                parentCode: region.parentCode
            )
        }

        return Group(
            code: region.code,
            name: region.name,
            parentCode: region.parentCode
        )
    }

    /// `수원시 장안구`처럼 구가 설치된 일반시의 이름만 추출합니다.
    nonisolated private static func cityName(
        from regionName: String
    ) -> String? {
        guard let separator = regionName.range(of: "시 ") else {
            return nil
        }

        return String(regionName[..<separator.lowerBound]) + "시"
    }
}
