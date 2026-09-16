//
//  PixelRegionLocator.swift
//  Picsel
//
//  Created by kosoobin on 9/10/26.
//

import Foundation

/// 좌표 하나가 속한 픽셀맵의 한 칸입니다.
///
/// StaticModels.swift에 격자 좌표를 쓰던 `PixelRegion`이 따로 있어 이름을 구분합니다.
/// 이쪽은 실제 경계 데이터(geojson) 기준입니다.
nonisolated struct PixelTile: Equatable, Sendable {
    /// 픽셀맵 경계 데이터의 코드입니다. ("4711" = 포항시)
    /// UserPixel.regionCode와 PicselMapRecord.regionCode가 이 값을 그대로 씁니다.
    let code: String

    /// 픽셀맵 타일에 찍히는 이름입니다. ("포항시")
    let name: String

    /// UserPixel.regionCode가 Int라 저장 직전에 변환합니다.
    /// 경계 데이터의 코드는 모두 11 이상이라 앞자리 0이 잘릴 일이 없습니다.
    var numericCode: Int? { Int(code) }
}

/// 좌표가 어느 픽셀 안에 있는지 찾습니다.
///
/// 픽셀맵이 그리는 경계 데이터(`sigungu_boundaries`)를 그대로 쓰기 때문에,
/// 여기서 찾은 코드는 PicselMapView가 칠하는 칸과 항상 일치합니다.
/// 관광 API의 지역 코드(RegionCodes.json)는 체계가 달라 여기서 쓰지 않습니다.
nonisolated enum PixelRegionLocator {

    /// 경계 밖으로 이 거리까지는 가장 가까운 지역으로 인정합니다.
    ///
    /// 해안 전망대·방파제·다리 위 좌표는 육지 폴리곤 바깥으로 조금 벗어납니다.
    /// (이가리 닻 전망대는 포항시 북구 경계에서 약 30m 바깥입니다.)
    /// 반대로 좌표가 아예 엉뚱할 때 엉뚱한 지역이 잡히지 않도록 상한을 둡니다.
    private static let snapDistanceMeters: Double = 3_000

    /// 경계 데이터는 한 번만 읽어 재사용합니다.
    /// static let이라 첫 접근 시 한 번만, 스레드 안전하게 초기화됩니다.
    private static let regions: [AdministrativeRegion] = {
        do {
            return try BundledGeoJSONRegionRepository().loadRegions()
        } catch {
            print("픽셀 경계 데이터를 읽지 못했습니다: \(error.localizedDescription)")
            return []
        }
    }()

    /// 읽어 둔 경계 데이터입니다.
    /// 픽셀 획득 화면이 지도를 그릴 때 같은 데이터를 다시 파싱하지 않고 재사용합니다.
    static var allRegions: [AdministrativeRegion] { regions }

    /// 경계 데이터를 미리 읽어 둡니다.
    /// 저장 버튼을 눌렀을 때 파싱 때문에 끊기지 않도록 화면 진입 시 호출합니다.
    static func preload() {
        _ = regions
    }

    /// 저장해 둔 코드로 픽셀을 되찾습니다.
    ///
    /// 여행에서 최종 목적지를 지우면 좌표가 사라져 tile(latitude:longitude:)로는
    /// 지역을 알 수 없습니다. 그때 Trip에 남아 있는 targetPixelCode로 복원합니다.
    static func tile(code: String) -> PixelTile? {
        guard let region = regions.first(where: { $0.code == code }) else { return nil }
        return PixelTile(code: region.code, name: region.name)
    }

    /// 좌표가 속한 픽셀을 찾습니다.
    ///
    /// 1. 폴리곤 안에 들어가는 지역을 먼저 찾고,
    /// 2. 없으면 경계에서 `snapDistanceMeters` 안에 있는 가장 가까운 지역을 씁니다.
    static func tile(latitude: Double, longitude: Double) -> PixelTile? {
        if let containing = regions.first(where: {
            $0.contains(latitude: latitude, longitude: longitude)
        }) {
            return PixelTile(code: containing.code, name: containing.name)
        }

        return nearestTile(latitude: latitude, longitude: longitude)
    }

    // MARK: - 경계 밖 좌표 처리

    private static func nearestTile(
        latitude: Double,
        longitude: Double
    ) -> PixelTile? {
        var nearest: AdministrativeRegion?
        var shortestDistance = Double.greatestFiniteMagnitude

        for region in regions {
            let distance = region.distanceToBoundary(
                latitude: latitude,
                longitude: longitude
            )

            if distance < shortestDistance {
                shortestDistance = distance
                nearest = region
            }
        }

        guard let nearest, shortestDistance <= snapDistanceMeters else { return nil }
        return PixelTile(code: nearest.code, name: nearest.name)
    }
}

// MARK: - 폴리곤 판정

private extension AdministrativeRegion {

    /// 구멍(호수·내륙 경계)을 뺀 실제 영역 안에 있는지 확인합니다.
    func contains(latitude: Double, longitude: Double) -> Bool {
        polygons.contains { polygon in
            guard polygon.exterior.encloses(latitude: latitude, longitude: longitude) else {
                return false
            }
            return !polygon.holes.contains {
                $0.encloses(latitude: latitude, longitude: longitude)
            }
        }
    }

    /// 이 지역의 경계선까지 가장 가까운 거리(m)입니다.
    func distanceToBoundary(latitude: Double, longitude: Double) -> Double {
        var shortest = Double.greatestFiniteMagnitude

        for polygon in polygons {
            let ring = polygon.exterior
            guard ring.count > 1 else { continue }

            for index in ring.indices {
                let start = ring[index]
                let end = ring[(index + 1) % ring.count]

                shortest = min(
                    shortest,
                    GeographicDistance.fromPoint(
                        latitude: latitude,
                        longitude: longitude,
                        toSegmentFrom: start,
                        to: end
                    )
                )
            }
        }

        return shortest
    }
}

private extension Array where Element == GeographicCoordinate {

    /// Ray casting. 점에서 가로로 선을 그었을 때 경계와 홀수 번 만나면 안쪽입니다.
    func encloses(latitude: Double, longitude: Double) -> Bool {
        guard count > 2 else { return false }

        var isInside = false
        var previousIndex = count - 1

        for index in indices {
            let current = self[index]
            let previous = self[previousIndex]

            // 두 점이 기준 위도를 사이에 두고 있을 때만 교차를 따집니다.
            if (current.latitude > latitude) != (previous.latitude > latitude) {
                let ratio = (latitude - current.latitude)
                    / (previous.latitude - current.latitude)
                let crossingLongitude = current.longitude
                    + ratio * (previous.longitude - current.longitude)

                if longitude < crossingLongitude {
                    isInside.toggle()
                }
            }

            previousIndex = index
        }

        return isInside
    }
}

// MARK: - 거리 계산

/// 시군구 한 칸 정도의 좁은 범위만 다루므로 위경도를 평면으로 근사합니다.
private enum GeographicDistance {

    private static let metersPerDegreeLatitude: Double = 111_320

    static func fromPoint(
        latitude: Double,
        longitude: Double,
        toSegmentFrom start: GeographicCoordinate,
        to end: GeographicCoordinate
    ) -> Double {
        let metersPerDegreeLongitude = metersPerDegreeLatitude
            * cos(latitude * .pi / 180)

        let pointX = longitude * metersPerDegreeLongitude
        let pointY = latitude * metersPerDegreeLatitude
        let startX = start.longitude * metersPerDegreeLongitude
        let startY = start.latitude * metersPerDegreeLatitude
        let endX = end.longitude * metersPerDegreeLongitude
        let endY = end.latitude * metersPerDegreeLatitude

        let segmentX = endX - startX
        let segmentY = endY - startY
        let squaredLength = segmentX * segmentX + segmentY * segmentY

        guard squaredLength > 0 else {
            return hypot(pointX - startX, pointY - startY)
        }

        // 선분 위에서 점과 가장 가까운 지점의 위치(0...1)를 구합니다.
        let rawProjection = ((pointX - startX) * segmentX + (pointY - startY) * segmentY)
            / squaredLength
        let projection = min(max(rawProjection, 0), 1)

        let closestX = startX + projection * segmentX
        let closestY = startY + projection * segmentY

        return hypot(pointX - closestX, pointY - closestY)
    }
}
