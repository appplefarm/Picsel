//
//  AdministrativeMapProjection.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/1/26.
//

import MapKit
import SwiftUI

nonisolated struct AdministrativeMapGridPoint: Hashable {
    let column: Int
    let row: Int

    static let zero = AdministrativeMapGridPoint(column: 0, row: 0)
}

/// 모든 행정구역이 같은 전국 좌표계와 픽셀 격자를 사용하도록 정규화합니다.
struct AdministrativeMapProjection {
    private let bounds: MKMapRect

    init(regions: [AdministrativeRegion]) {
        let mapPoints = regions.flatMap { region in
            region.polygons.flatMap { polygon in
                [polygon.exterior] + polygon.holes
            }
        }
        .flatMap { $0 }
        .map { coordinate in
            Self.mapPoint(coordinate)
        }

        guard let first = mapPoints.first else {
            bounds = .null
            return
        }

        var minimumX = first.x
        var maximumX = first.x
        var minimumY = first.y
        var maximumY = first.y

        for point in mapPoints.dropFirst() {
            minimumX = min(minimumX, point.x)
            maximumX = max(maximumX, point.x)
            minimumY = min(minimumY, point.y)
            maximumY = max(maximumY, point.y)
        }

        bounds = MKMapRect(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX,
            height: maximumY - minimumY
        )
    }

    var isEmpty: Bool {
        bounds.isNull || bounds.isEmpty
    }

    /// 전국 경계의 가로를 `horizontalResolution`개의 정사각 격자로 나눕니다.
    /// 모든 시도가 같은 기준점과 격자 크기를 사용하므로 경계가 서로 맞물립니다.
    func gridPoint(
        for coordinate: GeographicCoordinate,
        horizontalResolution: Int
    ) -> AdministrativeMapGridPoint {
        guard !isEmpty else { return .zero }

        let resolution = max(horizontalResolution, 1)
        let gridSize = bounds.size.width / Double(resolution)
        let mapPoint = Self.mapPoint(coordinate)

        return AdministrativeMapGridPoint(
            column: Int(
                ((mapPoint.x - bounds.origin.x) / gridSize).rounded()
            ),
            row: Int(
                ((mapPoint.y - bounds.origin.y) / gridSize).rounded()
            )
        )
    }

    func point(
        for gridPoint: AdministrativeMapGridPoint,
        horizontalResolution: Int,
        in rect: CGRect,
        padding: CGFloat
    ) -> CGPoint {
        guard !isEmpty else { return .zero }

        let resolution = max(horizontalResolution, 1)
        let gridSize = bounds.size.width / Double(resolution)
        let mapPoint = MKMapPoint(
            x: bounds.origin.x + Double(gridPoint.column) * gridSize,
            y: bounds.origin.y + Double(gridPoint.row) * gridSize
        )

        return projectedPoint(mapPoint, in: rect, padding: padding)
    }

    private func projectedPoint(
        _ mapPoint: MKMapPoint,
        in rect: CGRect,
        padding: CGFloat
    ) -> CGPoint {
        let innerRect = rect.insetBy(dx: padding, dy: padding)
        let scale = min(
            Double(innerRect.width) / bounds.size.width,
            Double(innerRect.height) / bounds.size.height
        )
        let renderedWidth = CGFloat(bounds.size.width * scale)
        let renderedHeight = CGFloat(bounds.size.height * scale)
        let originX = innerRect.minX + (innerRect.width - renderedWidth) / 2
        let originY = innerRect.minY + (innerRect.height - renderedHeight) / 2

        return CGPoint(
            x: originX + CGFloat((mapPoint.x - bounds.origin.x) * scale),
            y: originY + CGFloat((mapPoint.y - bounds.origin.y) * scale)
        )
    }

    // MARK: - 동쪽 섬 당기기

    /// 이 경도보다 동쪽에 있는 섬은 본토 쪽으로 당겨서 그립니다.
    private static let farEastLongitude = 130.0

    /// 당긴 뒤 남길 거리의 비율입니다. 0이면 경계선에 붙고, 1이면 실제 위치입니다.
    private static let farEastPullIn = 0.25

    /// 좌표를 화면 좌표계의 기준점으로 바꿉니다.
    ///
    /// 울릉도(130.9°)와 독도(131.9°)는 본토에서 아주 멀어서, 실제 위치 그대로 넣으면
    /// 전국 경계 상자가 가로로 늘어납니다. 재 보면 섬 두 개가 상자 폭의 31%를 차지하고,
    /// 세로로 긴 화면에서는 가로에 먼저 걸려 지도 전체가 그만큼 작게 그려집니다.
    ///
    /// 그래서 종이 지도에서 흔히 하듯 두 섬을 본토 쪽으로 당겨 그립니다.
    /// 지도에 보이는 위치는 실제 경도가 아니지만, 지도가 1.2배 이상 커집니다.
    ///
    /// 여행이 어느 픽셀에 속하는지 판정하는 일(PixelRegionLocator)은
    /// 원본 좌표로 따로 하므로 이 보정에 영향을 받지 않습니다.
    private static func mapPoint(_ coordinate: GeographicCoordinate) -> MKMapPoint {
        var longitude = coordinate.longitude

        if longitude > farEastLongitude {
            longitude = farEastLongitude
                + (longitude - farEastLongitude) * farEastPullIn
        }

        return MKMapPoint(
            CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: longitude
            )
        )
    }
}
