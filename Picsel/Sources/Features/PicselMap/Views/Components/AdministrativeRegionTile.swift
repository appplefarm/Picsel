//
//  AdministrativeRegionTile.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/1/26.
//

import SwiftUI

/// 실제 행정구역 경계 모양을 그대로 누를 수 있는 하나의 타일입니다.
struct AdministrativeRegionTile: View {
    let region: AdministrativeRegion
    let projection: AdministrativeMapProjection
    let pixelResolution: Int
    let isUnlocked: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        let geometry = AdministrativeRegionTileGeometry(
            region: region,
            projection: projection,
            pixelResolution: pixelResolution
        )
        let shape = AdministrativeRegionTileShape(geometry: geometry)
        let outline = AdministrativeBoundaryOutlineShape(geometry: geometry)

        Button(action: onSelect) {
            shape
                .fill(
                    fillColor,
                    style: FillStyle(eoFill: true, antialiased: false)
                )
                .overlay {
                    outline
                        .stroke(
                            strokeColor,
                            style: StrokeStyle(
                                lineWidth: strokeWidth,
                                lineCap: .square,
                                lineJoin: .miter
                            )
                        )
                        .allowsHitTesting(false)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .buttonStyle(.plain)
        .contentShape(.interaction, shape, eoFill: true)
        .accessibilityLabel(region.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("이중 탭하면 해당 지역을 선택합니다")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fillColor: Color {
        if isSelected {
            return .accentColor
        }
        return isUnlocked ? .primary.opacity(0.7) : Color(.systemGray5)
    }

    private var strokeColor: Color {
        .black.opacity(isSelected ? 0.85 : 0.65)
    }

    private var strokeWidth: CGFloat {
        isSelected ? 0.8 : 0.45
    }

    private var accessibilityValue: String {
        if isSelected {
            return isUnlocked ? "해금됨, 선택됨" : "잠김, 선택됨"
        }
        return isUnlocked ? "해금됨" : "잠김"
    }
}

private struct AdministrativeRegionTileShape: Shape {
    let geometry: AdministrativeRegionTileGeometry

    func path(in rect: CGRect) -> Path {
        geometry.fillPath(in: rect)
    }
}

struct AdministrativeBoundaryOutlineShape: Shape {
    let geometry: AdministrativeRegionTileGeometry

    func path(in rect: CGRect) -> Path {
        geometry.outlinePath(in: rect)
    }
}

/// 한 지역 안에서 두 번 나타나는 공유 경계는 제거하고 외곽선만 만듭니다.
struct AdministrativeRegionTileGeometry {
    private let projection: AdministrativeMapProjection
    private let pixelResolution: Int
    private let rings: [[AdministrativeMapGridPoint]]

    init(
        region: AdministrativeRegion,
        projection: AdministrativeMapProjection,
        pixelResolution: Int
    ) {
        self.init(
            polygons: region.polygons,
            projection: projection,
            pixelResolution: pixelResolution
        )
    }

    init(
        polygons: [AdministrativeRegionPolygon],
        projection: AdministrativeMapProjection,
        pixelResolution: Int
    ) {
        self.projection = projection
        self.pixelResolution = pixelResolution
        rings = polygons.flatMap { polygon in
            [polygon.exterior] + polygon.holes
        }
        .compactMap { ring in
            Self.pixelRing(
                ring,
                projection: projection,
                pixelResolution: pixelResolution
            )
        }
    }

    func fillPath(in rect: CGRect) -> Path {
        var path = Path()

        for ring in rings {
            guard let first = ring.first else { continue }
            path.move(to: screenPoint(for: first, in: rect))
            ring.dropFirst().forEach { point in
                path.addLine(to: screenPoint(for: point, in: rect))
            }
            path.closeSubpath()
        }

        return path
    }

    func outlinePath(in rect: CGRect) -> Path {
        var edgeCounts: [GridEdge: Int] = [:]

        for ring in rings {
            guard let first = ring.first else { continue }
            let closedRing = ring.dropFirst().map { $0 } + [first]

            for (start, end) in zip(ring, closedRing) where start != end {
                edgeCounts[GridEdge(start, end), default: 0] += 1
            }
        }

        var path = Path()
        for (edge, count) in edgeCounts where !count.isMultiple(of: 2) {
            path.move(to: screenPoint(for: edge.start, in: rect))
            path.addLine(to: screenPoint(for: edge.end, in: rect))
        }
        return path
    }

    private static func pixelRing(
        _ ring: [GeographicCoordinate],
        projection: AdministrativeMapProjection,
        pixelResolution: Int
    ) -> [AdministrativeMapGridPoint]? {
        guard ring.count >= 3 else { return nil }

        var gridPoints: [AdministrativeMapGridPoint] = []

        for coordinate in ring {
            let point = projection.gridPoint(
                for: coordinate,
                horizontalResolution: pixelResolution
            )

            if gridPoints.last != point {
                gridPoints.append(point)
            }
        }

        if let first = gridPoints.first,
           let last = gridPoints.last,
           first == last {
            gridPoints.removeLast()
        }

        guard gridPoints.count >= 3, let first = gridPoints.first else {
            return nil
        }

        var expandedPoints = [first]
        var current = first
        for next in gridPoints.dropFirst() {
            expandedPoints.append(contentsOf: staircasePoints(from: current, to: next))
            current = next
        }
        expandedPoints.append(contentsOf: staircasePoints(from: current, to: first))

        if expandedPoints.last == first {
            expandedPoints.removeLast()
        }
        return expandedPoints.count >= 3 ? expandedPoints : nil
    }

    /// 대각선을 픽셀 격자의 가로·세로 선분으로 바꿔 계단형 경계를 만듭니다.
    private static func staircasePoints(
        from start: AdministrativeMapGridPoint,
        to end: AdministrativeMapGridPoint
    ) -> [AdministrativeMapGridPoint] {
        let columnDelta = end.column - start.column
        let rowDelta = end.row - start.row
        let stepCount = max(abs(columnDelta), abs(rowDelta))

        guard stepCount > 0 else { return [] }

        var result: [AdministrativeMapGridPoint] = []
        var previous = start

        for step in 1...stepCount {
            let progress = Double(step) / Double(stepCount)
            let next = AdministrativeMapGridPoint(
                column: Int(
                    (Double(start.column) + Double(columnDelta) * progress)
                        .rounded()
                ),
                row: Int(
                    (Double(start.row) + Double(rowDelta) * progress)
                        .rounded()
                )
            )

            guard next != previous else { continue }

            if previous.column != next.column,
               previous.row != next.row {
                let corners = [
                    AdministrativeMapGridPoint(
                        column: next.column,
                        row: previous.row
                    ),
                    AdministrativeMapGridPoint(
                        column: previous.column,
                        row: next.row
                    )
                ]
                result.append(corners.min(by: isOrderedBefore) ?? corners[0])
            }

            result.append(next)
            previous = next
        }

        return result
    }

    /// 어느 방향으로 경계를 순회해도 같은 꼭지점을 선택합니다.
    nonisolated private static func isOrderedBefore(
        _ lhs: AdministrativeMapGridPoint,
        _ rhs: AdministrativeMapGridPoint
    ) -> Bool {
        lhs.column == rhs.column
            ? lhs.row < rhs.row
            : lhs.column < rhs.column
    }

    private func screenPoint(
        for gridPoint: AdministrativeMapGridPoint,
        in rect: CGRect
    ) -> CGPoint {
        projection.point(
            for: gridPoint,
            horizontalResolution: pixelResolution,
            in: rect,
            padding: 18
        )
    }

    private struct GridEdge: Hashable {
        let start: AdministrativeMapGridPoint
        let end: AdministrativeMapGridPoint

        init(
            _ first: AdministrativeMapGridPoint,
            _ second: AdministrativeMapGridPoint
        ) {
            if AdministrativeRegionTileGeometry.isOrderedBefore(first, second) {
                start = first
                end = second
            } else {
                start = second
                end = first
            }
        }
    }
}
