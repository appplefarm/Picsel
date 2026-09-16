	//
//  PixelMapIslandLayoutPreviews.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

#if DEBUG
import SwiftUI

/// 섬 배치 보정을 눈으로 확인하는 프리뷰입니다.
///
/// 독도·백령도·제주는 화면에서만 자리를 옮겨 그립니다. (PixelMapIslandLayout)
/// 값을 바꾸면 여기서 바로 결과가 보입니다.
private struct IslandLayoutPreview: View {

    /// 옮긴 섬을 눈에 띄게 칠할지입니다.
    var highlightsIslands: Bool = true

    private let regions = PixelRegionLocator.allRegions

    /// 자리를 옮긴 지역들입니다.
    private static let movedCodes: Set<String> = ["47940", "28720", "50110", "50130"]

    var body: some View {
        AdministrativeRegionMapView(
            regions: regions,
            unlockedRegionCodes: highlightsIslands ? Self.movedCodes : [],
            selectedRegionCode: nil,
            onSelectRegion: { _ in }
        )
        .background(PicselColor.backgroundWarmWhite)
    }
}

#Preview("배치 확인 (옮긴 섬 강조)") {
    IslandLayoutPreview()
}

#Preview("배치 확인 (전체 잠김)") {
    IslandLayoutPreview(highlightsIslands: false)
}

/// 보정 전과 후를 숫자로 비교합니다. 콘솔에 찍힙니다.
#Preview("수치 비교") {
    IslandLayoutComparison()
}

private struct IslandLayoutComparison: View {

    @State private var lines: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .task { lines = measure() }
    }

    private func measure() -> [String] {
        let regions = PixelRegionLocator.allRegions
        guard !regions.isEmpty else { return ["경계 데이터를 읽지 못했습니다."] }

        var result: [String] = []

        let original = bounds(regions.flatMap(\.polygons))
        let display = bounds(regions.flatMap(\.displayPolygons))

        result.append("── 전체 경계 상자 ──")
        result.append(String(
            format: "원본  경도 %.3f~%.3f  폭 %.3f",
            original.minimumLongitude, original.maximumLongitude,
            original.maximumLongitude - original.minimumLongitude
        ))
        result.append(String(
            format: "표시  경도 %.3f~%.3f  폭 %.3f",
            display.minimumLongitude, display.maximumLongitude,
            display.maximumLongitude - display.minimumLongitude
        ))

        let cell = (display.maximumLongitude - display.minimumLongitude) / 128
        result.append(String(format: "격자 한 칸 %.4f°", cell))
        result.append("")

        result.append("── 옮긴 섬 ──")
        for code in ["47940", "28720", "50110", "50130"] {
            guard let region = regions.first(where: { $0.containsAnyRegion(in: [code]) })
            else { continue }

            let before = bounds(region.polygons)
            let after = bounds(region.displayPolygons)
            result.append("\(region.name) (\(code))")
            result.append(String(
                format: "  전  %.3f~%.3f / %.3f~%.3f",
                before.minimumLongitude, before.maximumLongitude,
                before.minimumLatitude, before.maximumLatitude
            ))
            result.append(String(
                format: "  후  %.3f~%.3f / %.3f~%.3f",
                after.minimumLongitude, after.maximumLongitude,
                after.minimumLatitude, after.maximumLatitude
            ))
        }

        // 독도가 실제로 몇 칸을 차지하는지. 1칸 미만이면 화면에서 사라집니다.
        if let ulleung = regions.first(where: { $0.containsAnyRegion(in: ["47940"]) }) {
            let dokdo = ulleung.displayPolygons
                .flatMap(\.exterior)
                .filter { $0.longitude > 130.2 }

            if !dokdo.isEmpty,
               let minimum = dokdo.map(\.longitude).min(),
               let maximum = dokdo.map(\.longitude).max() {
                result.append("")
                result.append(String(
                    format: "독도 가로 %.4f° → 격자 %.1f칸",
                    maximum - minimum, (maximum - minimum) / cell
                ))
            }
        }

        return result
    }

    private func bounds(
        _ polygons: [AdministrativeRegionPolygon]
    ) -> (minimumLongitude: Double, maximumLongitude: Double,
          minimumLatitude: Double, maximumLatitude: Double) {

        let points = polygons.flatMap { [$0.exterior] + $0.holes }.flatMap { $0 }
        let longitudes = points.map(\.longitude)
        let latitudes = points.map(\.latitude)

        return (
            longitudes.min() ?? 0, longitudes.max() ?? 0,
            latitudes.min() ?? 0, latitudes.max() ?? 0
        )
    }
}
#endif
