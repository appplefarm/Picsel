//
//  AdministrativeRegionMapView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/1/26.
//

import SwiftUI

/// 경계·해금 코드·선택 콜백만으로 재사용하는 지도입니다.
/// 화면 제목, 기록 카드, 탭바, 데이터 저장소는 포함하지 않습니다.
struct AdministrativeRegionMapView: View {
    let regions: [AdministrativeRegion]
    let unlockedRegionCodes: Set<String>
    let selectedRegionCode: String?
    let pixelResolution: Int
    let onSelectRegion: (String?) -> Void

    private let projection: AdministrativeMapProjection
    private let provinceBoundaries: [ProvinceBoundary]
    private let minimumScale: CGFloat = 1
    private let maximumScale: CGFloat = 4

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureOffset: CGSize = .zero

    init(
        regions: [AdministrativeRegion],
        unlockedRegionCodes: Set<String> = [],
        selectedRegionCode: String? = nil,
        pixelResolution: Int = 128,
        onSelectRegion: @escaping (String?) -> Void
    ) {
        self.regions = regions
        self.unlockedRegionCodes = unlockedRegionCodes
        self.selectedRegionCode = selectedRegionCode
        self.pixelResolution = pixelResolution
        self.onSelectRegion = onSelectRegion
        projection = AdministrativeMapProjection(regions: regions)
        provinceBoundaries = Dictionary(
            grouping: regions,
            by: { $0.parentCode ?? String($0.code.prefix(2)) }
        )
        .map { code, members in
            ProvinceBoundary(
                code: code,
                polygons: members.flatMap(\.polygons)
            )
        }
        .sorted { $0.code < $1.code }
    }

    var body: some View {
        GeometryReader { geometry in
            let renderedScale = clampedScale(scale * gestureScale)
            let renderedOffset = clampedOffset(
                offset + gestureOffset,
                in: geometry.size,
                scale: renderedScale
            )

            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectRegion(nil)
                    }

                ZStack {
                    ForEach(regions) { region in
                        AdministrativeRegionTile(
                            region: region,
                            projection: projection,
                            pixelResolution: pixelResolution,
                            isUnlocked: region.containsAnyRegion(
                                in: unlockedRegionCodes
                            ),
                            isSelected: selectedRegionCode == region.code
                        ) {
                            onSelectRegion(region.code)
                        }
                        .zIndex(selectedRegionCode == region.code ? 1 : 0)
                    }

                    ForEach(provinceBoundaries) { boundary in
                        AdministrativeBoundaryOutlineShape(
                            geometry: AdministrativeRegionTileGeometry(
                                polygons: boundary.polygons,
                                projection: projection,
                                pixelResolution: pixelResolution
                            )
                        )
                        .stroke(
                            .black.opacity(0.78),
                            style: StrokeStyle(
                                lineWidth: 0.7,
                                lineCap: .square,
                                lineJoin: .miter
                            )
                        )
                        .allowsHitTesting(false)
                        .zIndex(2)
                    }
                }
                .scaleEffect(renderedScale)
                .offset(renderedOffset)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(magnifyGesture(in: geometry.size))
            .simultaneousGesture(dragGesture(in: geometry.size))
            .clipped()
        }
        .accessibilityElement(children: .contain)
    }

    private func magnifyGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .updating($gestureScale) { value, gestureScale, _ in
                gestureScale = value.magnification
            }
            .onEnded { value in
                scale = clampedScale(scale * value.magnification)
                offset = clampedOffset(offset, in: size, scale: scale)
            }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($gestureOffset) { value, gestureOffset, _ in
                guard scale * gestureScale > minimumScale else { return }
                gestureOffset = value.translation
            }
            .onEnded { value in
                guard scale > minimumScale else {
                    offset = .zero
                    return
                }

                offset = clampedOffset(
                    offset + value.translation,
                    in: size,
                    scale: scale
                )
            }
    }

    private func clampedScale(_ proposedScale: CGFloat) -> CGFloat {
        min(max(proposedScale, minimumScale), maximumScale)
    }

    private func clampedOffset(
        _ proposedOffset: CGSize,
        in size: CGSize,
        scale: CGFloat
    ) -> CGSize {
        let maximumX = size.width * (scale - 1) / 2
        let maximumY = size.height * (scale - 1) / 2

        return CGSize(
            width: min(max(proposedOffset.width, -maximumX), maximumX),
            height: min(max(proposedOffset.height, -maximumY), maximumY)
        )
    }
}

private struct ProvinceBoundary: Identifiable {
    let code: String
    let polygons: [AdministrativeRegionPolygon]

    var id: String { code }
}

private extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(
            width: lhs.width + rhs.width,
            height: lhs.height + rhs.height
        )
    }
}
