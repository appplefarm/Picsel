//
//  AdministrativeRegion.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/1/26.
//

import Foundation

/// 지도 경계 데이터와 사용자의 획득 상태를 분리하기 위한 정적 지역 모델입니다.
nonisolated struct AdministrativeRegion: Identifiable, Hashable, Sendable {
    let code: String
    let name: String
    let parentCode: String?
    let constituentCodes: Set<String>

    /// 실제 지리 좌표입니다. 좌표가 어느 픽셀에 속하는지 **판정할 때** 씁니다.
    let polygons: [AdministrativeRegionPolygon]

    /// 화면에 **그릴 때** 쓰는 좌표입니다.
    ///
    /// 독도처럼 너무 작거나, 백령도·제주처럼 멀리 떨어져 지도를 작게 만드는 섬은
    /// 보기 좋은 자리로 옮겨 그립니다. (PixelMapIslandLayout)
    /// 옮길 필요가 없는 지역은 `polygons`와 같습니다.
    let displayPolygons: [AdministrativeRegionPolygon]

    var id: String { code }

    func containsAnyRegion(in regionCodes: Set<String>) -> Bool {
        regionCodes.contains(code)
            || !constituentCodes.isDisjoint(with: regionCodes)
    }
}

/// 섬과 내륙 호수를 포함한 MultiPolygon을 표현할 수 있는 단위입니다.
nonisolated struct AdministrativeRegionPolygon: Hashable, Sendable {
    let exterior: [GeographicCoordinate]
    let holes: [[GeographicCoordinate]]

    init(
        exterior: [GeographicCoordinate],
        holes: [[GeographicCoordinate]] = []
    ) {
        self.exterior = exterior
        self.holes = holes
    }
}

nonisolated struct GeographicCoordinate: Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}
