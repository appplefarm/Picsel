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
    let polygons: [AdministrativeRegionPolygon]

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
