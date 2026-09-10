//
//  PixelMapCamera.swift
//  Picsel
//
//  Created by kosoobin on 9/12/26.
//

import SwiftUI

/// 지도 전체에 걸 확대·이동 값입니다.
///
/// 지도는 전국 좌표계 위에 모든 지역을 겹쳐 그리기 때문에,
/// 특정 지역으로 "카메라를 옮기는" 일이 곧 전체에 scale과 offset을 거는 일이 됩니다.
struct PixelMapCamera: Equatable {
    var scale: CGFloat
    var offset: CGSize

    /// 전국이 한눈에 들어오는 기본 상태입니다.
    static let whole = PixelMapCamera(scale: 1, offset: .zero)

    /// 지역 하나가 화면을 채우도록 확대한 상태입니다.
    /// 지역을 찾지 못하면 nil을 돌려주고, 호출한 쪽은 연출 없이 전국을 보여 줍니다.
    static func focused(
        onRegionCode regionCode: String,
        in size: CGSize
    ) -> PixelMapCamera? {
        guard size.width > 0, size.height > 0,
              let target = PixelMapGeometryCache.screenRect(
                  forRegionCode: regionCode,
                  in: size
              ),
              target.width > 0, target.height > 0
        else { return nil }

        // 화면을 꽉 채우면 답답해서 여백을 남깁니다.
        let fillRatio: CGFloat = 0.55
        let fitScale = min(
            size.width / target.width,
            size.height / target.height
        ) * fillRatio

        // 아주 작은 섬 하나가 걸리면 배율이 폭주하므로 상한을 둡니다.
        let scale = min(max(fitScale, 1), 12)

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let offset = CGSize(
            width: (center.x - target.midX) * scale,
            height: (center.y - target.midY) * scale
        )

        return PixelMapCamera(scale: scale, offset: offset)
    }
}

/// 지역별 경계 도형을 한 번만 만들어 재사용합니다.
///
/// 계단형 경계를 만드는 계산이 가벼운 편이 아니라서,
/// 뷰가 다시 그려질 때마다 161개를 새로 만들면 연출이 끊깁니다.
/// 경계 데이터가 앱 내내 바뀌지 않으므로 정적으로 들고 있어도 안전합니다.
@MainActor
enum PixelMapGeometryCache {

    /// 픽셀맵 탭과 같은 격자 밀도를 씁니다.
    static let pixelResolution = 128

    /// AdministrativeRegionTileGeometry가 좌표를 화면으로 옮길 때 쓰는 여백입니다.
    /// 카메라 계산도 같은 값을 써야 확대한 위치가 어긋나지 않습니다.
    private static let projectionPadding: CGFloat = 18

    static let projection = AdministrativeMapProjection(
        regions: PixelRegionLocator.allRegions
    )

    static let tiles: [PixelMapTile] = PixelRegionLocator.allRegions.map { region in
        PixelMapTile(
            region: region,
            geometry: AdministrativeRegionTileGeometry(
                region: region,
                projection: projection,
                pixelResolution: pixelResolution
            )
        )
    }

    /// 지역 하나가 화면에서 차지하는 사각형입니다.
    static func screenRect(
        forRegionCode regionCode: String,
        in size: CGSize
    ) -> CGRect? {
        guard let region = PixelRegionLocator.allRegions.first(where: {
            $0.containsAnyRegion(in: [regionCode])
        }) else { return nil }

        guard let bounds = gridBounds(of: region) else { return nil }

        let rect = CGRect(origin: .zero, size: size)
        let first = projection.point(
            for: bounds.topLeading,
            horizontalResolution: pixelResolution,
            in: rect,
            padding: projectionPadding
        )
        let second = projection.point(
            for: bounds.bottomTrailing,
            horizontalResolution: pixelResolution,
            in: rect,
            padding: projectionPadding
        )

        return CGRect(
            x: min(first.x, second.x),
            y: min(first.y, second.y),
            width: abs(second.x - first.x),
            height: abs(second.y - first.y)
        )
    }

    /// 지역이 차지하는 격자 칸의 좌상단·우하단입니다.
    private static func gridBounds(
        of region: AdministrativeRegion
    ) -> PixelMapGridBounds? {
        var minimumColumn = Int.max
        var maximumColumn = Int.min
        var minimumRow = Int.max
        var maximumRow = Int.min

        for polygon in region.polygons {
            for coordinate in polygon.exterior {
                let point = projection.gridPoint(
                    for: coordinate,
                    horizontalResolution: pixelResolution
                )
                minimumColumn = min(minimumColumn, point.column)
                maximumColumn = max(maximumColumn, point.column)
                minimumRow = min(minimumRow, point.row)
                maximumRow = max(maximumRow, point.row)
            }
        }

        guard minimumColumn <= maximumColumn, minimumRow <= maximumRow else {
            return nil
        }

        return PixelMapGridBounds(
            topLeading: AdministrativeMapGridPoint(
                column: minimumColumn,
                row: minimumRow
            ),
            bottomTrailing: AdministrativeMapGridPoint(
                column: maximumColumn,
                row: maximumRow
            )
        )
    }
}

/// 지역 하나와 미리 만들어 둔 경계 도형입니다.
struct PixelMapTile: Identifiable {
    let region: AdministrativeRegion
    let geometry: AdministrativeRegionTileGeometry

    var id: String { region.code }
}

/// 지역이 걸쳐 있는 격자 범위입니다.
private struct PixelMapGridBounds {
    let topLeading: AdministrativeMapGridPoint
    let bottomTrailing: AdministrativeMapGridPoint
}
