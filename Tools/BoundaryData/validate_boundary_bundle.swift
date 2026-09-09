//
//  validate_boundary_bundle.swift
//  Picsel boundary validation (macOS command-line test)
//
//  Created by Jonghyeon Lee on 9/9/26.
//

import Foundation

/// Compile with the real region model, repository and grouper; no duplicated decoder.
@main
struct BoundaryBundleValidation {
    static func main() throws {
        guard CommandLine.arguments.count == 2,
              let bundle = Bundle(path: CommandLine.arguments[1]) else {
            fatalError("Pass the path of a bundle containing the 20260909 GeoJSON")
        }
        let repository = BundledGeoJSONRegionRepository(
            bundle: bundle,
            resourceName: "sigungu_boundaries_20260909"
        )
        let regions = try repository.loadRegions()
        precondition(regions.count == 161, "Expected 161 selectable map tiles")
        precondition(Set(regions.map(\.id)).count == regions.count)
        let codes = regions.flatMap(\.constituentCodes)
        precondition(codes.count == 256 && Set(codes).count == 256,
                     "Each source SIG must belong to exactly one tile")

        func tile(_ code: String) -> AdministrativeRegion {
            guard let result = regions.first(where: { $0.code == code }) else {
                fatalError("Missing tile: \(code)")
            }
            return result
        }

        precondition(tile("28").constituentCodes.isSuperset(of: ["28125", "28155", "28275", "28290"]))
        precondition(tile("28").constituentCodes.count == 11)
        precondition(tile("27").containsAnyRegion(in: ["27200"]))
        precondition(!tile("26").containsAnyRegion(in: ["27200"]))
        precondition(tile("26").containsAnyRegion(in: ["26290"]))
        precondition(tile("4159").name == "화성시")
        precondition(tile("4159").constituentCodes == ["41591", "41593", "41595", "41597"])
        precondition(tile("4119").name == "부천시")
        precondition(tile("29").parentCode == "12")
        precondition(tile("29").constituentCodes == ["12210", "12240", "12270", "12300", "12330"])
        precondition(tile("12110").name == "목포시")
        precondition(!tile("29").containsAnyRegion(in: ["12110"]))

        for region in regions {
            precondition(!region.polygons.isEmpty)
            for polygon in region.polygons {
                for ring in [polygon.exterior] + polygon.holes {
                    precondition(ring.count >= 4 && ring.first == ring.last)
                    for coordinate in ring {
                        precondition((124...132).contains(coordinate.longitude))
                        precondition((32...39.5).contains(coordinate.latitude))
                    }
                }
            }
        }

        // The former input still groups 광주(29) independently from 전남(46).
        let legacy = AdministrativeRegion(
            code: "29110", name: "동구", parentCode: "29",
            constituentCodes: ["29110"], polygons: []
        )
        let legacyGroup = AdministrativeRegionGrouper.group([legacy])[0]
        precondition(legacyGroup.code == "29" && legacyGroup.parentCode == nil)
        print("PASS: 256 source regions → 161 unique selectable tiles, grouping and coordinate checks")
    }
}
