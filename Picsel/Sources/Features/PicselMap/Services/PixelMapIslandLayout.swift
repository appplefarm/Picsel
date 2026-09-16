//
//  PixelMapIslandLayout.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import Foundation

/// 지도에 그릴 때만 위치를 옮기는 섬들입니다.
///
/// 실제 지리 좌표를 그대로 쓰면 지도가 작아지거나 아예 안 보이는 섬이 생깁니다.
///
/// - 독도는 폭이 0.006°(약 500m)라 픽셀 격자에서 한 칸도 못 채우고 사라집니다.
/// - 독도·울릉도가 동쪽으로 멀리 떨어져 있어 경계 상자를 가로로 늘립니다.
///   그러면 세로로 긴 화면에서 가로에 먼저 걸려 지도 전체가 작게 그려집니다.
/// - 백령도가 서쪽 끝을 혼자 밀고 있어 왼쪽에 빈 공간이 크게 남습니다.
///
/// 종이 지도가 독도를 따로 떼어 크게 그리듯, 화면 표시 위치만 옮깁니다.
///
/// **원본 좌표는 건드리지 않습니다.**
/// `AdministrativeRegion.polygons`가 원본이고 판정에 쓰이며,
/// 여기서 만든 값은 `displayPolygons`로 따로 들어가 그리기에만 쓰입니다.
/// 그래서 `PixelRegionLocator`의 픽셀 판정은 이 보정에 영향받지 않습니다.
nonisolated enum PixelMapIslandLayout {

    /// 섬 하나를 옮기는 규칙입니다.
    struct Adjustment: Sendable {
        let name: String

        /// 이 코드로 시작하는 지역에만 적용합니다. 제주는 "50"처럼 시도 단위도 됩니다.
        let regionCodePrefix: String

        /// 한 지역 안에서 이 경도 범위에 드는 좌표만 옮깁니다.
        ///
        /// 울릉군처럼 한 지역에 울릉도와 독도가 같이 들어 있을 때 둘을 갈라냅니다.
        /// nil이면 그 지역 전체를 옮깁니다.
        let longitudeRange: Range<Double>?

        /// 원본 중심을 기준으로 한 확대 배율입니다. 1이면 크기를 바꾸지 않습니다.
        let scale: Double

        /// 옮긴 뒤 중심이 놓일 자리입니다.
        let targetCenter: GeographicCoordinate
    }

    /// 화면 배치 규칙입니다. 값은 시안 없이 정한 것이라 눈으로 보고 조정해도 됩니다.
    ///
    /// 원본 위치
    /// | 대상 | 경도 | 위도 |
    /// |---|---|---|
    /// | 울릉도 | 130.791~130.939 | 37.454~37.548 |
    /// | 독도 | 131.862~131.867 | 37.240~37.245 |
    /// | 백령도권 | 124.610~124.770 | 37.760~37.984 |
    private static let adjustments: [Adjustment] = [
        // 본토 동해안(경도 약 129.6)에서 0.4° 정도 떨어뜨립니다.
        Adjustment(
            name: "울릉도",
            regionCodePrefix: "47940",
            longitudeRange: 130.0..<131.5,
            scale: 1,
            targetCenter: GeographicCoordinate(latitude: 37.501, longitude: 130.05)
        ),

        // 격자 한 칸이 약 0.041°라, 14배로 키워야 두 칸쯤 되어 눈에 보입니다.
        // 울릉도 오른쪽 아래에 둡니다.
        Adjustment(
            name: "독도",
            regionCodePrefix: "47940",
            longitudeRange: 131.5..<133.0,
            scale: 14,
            targetCenter: GeographicCoordinate(latitude: 37.28, longitude: 130.33)
        ),

        // 서쪽 끝을 혼자 밀고 있어 동쪽으로 당깁니다.
        // 신안군 서쪽 끝(125.088)보다 안쪽으로 들어오지 않게 둡니다.
        Adjustment(
            name: "백령도",
            regionCodePrefix: "28720",
            longitudeRange: 124.0..<125.2,
            scale: 1,
            targetCenter: GeographicCoordinate(latitude: 37.872, longitude: 125.23)
        )
    ]

    // MARK: - 적용

    /// 지역 하나의 폴리곤을 화면 표시용으로 옮깁니다.
    /// 규칙에 걸리지 않으면 원본을 그대로 돌려줍니다.
    static func displayPolygons(
        of polygons: [AdministrativeRegionPolygon],
        regionCode: String
    ) -> [AdministrativeRegionPolygon] {

        let matched = adjustments.filter { regionCode.hasPrefix($0.regionCodePrefix) }
        guard !matched.isEmpty else { return polygons }

        // 규칙마다 원본 중심이 달라서, 좌표를 옮기기 전에 먼저 다 구해 둡니다.
        let origins = matched.compactMap { adjustment -> (Adjustment, GeographicCoordinate)? in
            guard let center = center(of: polygons, in: adjustment.longitudeRange) else {
                return nil
            }
            return (adjustment, center)
        }

        guard !origins.isEmpty else { return polygons }

        return polygons.map { polygon in
            AdministrativeRegionPolygon(
                exterior: polygon.exterior.map { move($0, by: origins) },
                holes: polygon.holes.map { $0.map { move($0, by: origins) } }
            )
        }
    }

    /// 좌표 하나에 맞는 규칙을 찾아 옮깁니다.
    private static func move(
        _ coordinate: GeographicCoordinate,
        by origins: [(Adjustment, GeographicCoordinate)]
    ) -> GeographicCoordinate {

        guard let (adjustment, origin) = origins.first(where: { adjustment, _ in
            adjustment.longitudeRange?.contains(coordinate.longitude) ?? true
        }) else { return coordinate }

        return GeographicCoordinate(
            latitude: adjustment.targetCenter.latitude
                + (coordinate.latitude - origin.latitude) * adjustment.scale,
            longitude: adjustment.targetCenter.longitude
                + (coordinate.longitude - origin.longitude) * adjustment.scale
        )
    }

    /// 범위에 드는 좌표들의 한가운데입니다. 확대·이동의 기준점이 됩니다.
    private static func center(
        of polygons: [AdministrativeRegionPolygon],
        in longitudeRange: Range<Double>?
    ) -> GeographicCoordinate? {

        var minimumLatitude = Double.infinity
        var maximumLatitude = -Double.infinity
        var minimumLongitude = Double.infinity
        var maximumLongitude = -Double.infinity

        for polygon in polygons {
            for coordinate in [polygon.exterior] + polygon.holes {
                for point in coordinate {
                    guard longitudeRange?.contains(point.longitude) ?? true else { continue }
                    minimumLatitude = min(minimumLatitude, point.latitude)
                    maximumLatitude = max(maximumLatitude, point.latitude)
                    minimumLongitude = min(minimumLongitude, point.longitude)
                    maximumLongitude = max(maximumLongitude, point.longitude)
                }
            }
        }

        guard minimumLatitude <= maximumLatitude else { return nil }

        return GeographicCoordinate(
            latitude: (minimumLatitude + maximumLatitude) / 2,
            longitude: (minimumLongitude + maximumLongitude) / 2
        )
    }
}
