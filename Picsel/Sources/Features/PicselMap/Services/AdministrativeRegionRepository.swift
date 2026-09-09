//
//  AdministrativeRegionRepository.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/1/26.
//

import Foundation

nonisolated protocol AdministrativeRegionRepository: Sendable {
    func loadRegions() throws -> [AdministrativeRegion]
}

nonisolated struct BundledGeoJSONRegionRepository: AdministrativeRegionRepository {
    private let bundle: Bundle
    private let resourceName: String

    init(
        bundle: Bundle = .main,
        resourceName: String = "sigungu_boundaries_2023"
    ) {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    func loadRegions() throws -> [AdministrativeRegion] {
        guard let resourceURL = bundle.url(
            forResource: resourceName,
            withExtension: "geojson"
        ) else {
            throw RegionRepositoryError.missingResource(resourceName)
        }

        let data = try Data(contentsOf: resourceURL)
        let collection = try JSONDecoder().decode(FeatureCollection.self, from: data)

        let sourceRegions = collection.features.compactMap(\.administrativeRegion)
        guard !sourceRegions.isEmpty else {
            throw RegionRepositoryError.emptyFeatureCollection
        }

        return AdministrativeRegionGrouper.group(sourceRegions)
    }
}

nonisolated enum RegionRepositoryError: LocalizedError {
    case missingResource(String)
    case emptyFeatureCollection

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            "\(name).geojson 파일을 찾을 수 없어요."
        case .emptyFeatureCollection:
            "GeoJSON에 표시할 행정구역 경계가 없어요."
        }
    }
}

nonisolated private struct FeatureCollection: Decodable {
    let features: [Feature]
}

nonisolated private struct Feature: Decodable {
    let properties: Properties
    let geometry: Geometry

    var administrativeRegion: AdministrativeRegion? {
        guard !geometry.polygons.isEmpty else { return nil }

        return AdministrativeRegion(
            code: properties.code,
            name: properties.name,
            parentCode: properties.parentCode,
            constituentCodes: [properties.code],
            polygons: geometry.polygons
        )
    }
}

nonisolated private struct Properties: Decodable {
    let code: String
    let name: String
    let parentCode: String?
}

nonisolated private struct Geometry: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }

    private enum GeometryType: String, Decodable {
        case polygon = "Polygon"
        case multiPolygon = "MultiPolygon"
    }

    let polygons: [AdministrativeRegionPolygon]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(GeometryType.self, forKey: .type)

        switch type {
        case .polygon:
            let rings = try container.decode(
                [[[Double]]].self,
                forKey: .coordinates
            )
            polygons = Self.makePolygon(from: rings).map { [$0] } ?? []

        case .multiPolygon:
            let polygonRings = try container.decode(
                [[[[Double]]]].self,
                forKey: .coordinates
            )
            polygons = polygonRings.compactMap(Self.makePolygon)
        }
    }

    nonisolated private static func makePolygon(
        from rings: [[[Double]]]
    ) -> AdministrativeRegionPolygon? {
        let convertedRings = rings.map { ring in
            ring.compactMap { position -> GeographicCoordinate? in
                guard position.count >= 2 else { return nil }
                return GeographicCoordinate(
                    latitude: position[1],
                    longitude: position[0]
                )
            }
        }

        guard let exterior = convertedRings.first, exterior.count >= 3 else {
            return nil
        }

        return AdministrativeRegionPolygon(
            exterior: exterior,
            holes: Array(convertedRings.dropFirst()).filter { $0.count >= 3 }
        )
    }
}
