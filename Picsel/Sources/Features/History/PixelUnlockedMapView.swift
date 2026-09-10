//
//  PixelUnlockedMapView.swift
//  Picsel
//
//  Created by kosoobin on 9/12/26.
//

import SwiftUI

/// 픽셀 획득 화면에 보여 줄 전국 픽셀맵입니다.
///
/// 픽셀맵 탭의 지도(AdministrativeRegionMapView)와 같은 경계·격자를 쓰지만,
/// 확대·선택 같은 상호작용이 없고 색과 연출이 다릅니다.
/// 그래서 그 화면의 타일 컴포넌트를 쓰지 않고 도형만 재사용합니다.
struct PixelUnlockedMapView: View {

    /// 이번 여행으로 새로 채운 칸입니다. 다른 칸보다 진하게 그립니다.
    let highlightedRegionCode: String?

    /// 이전에 채워 둔 칸들입니다.
    let unlockedRegionCodes: Set<String>

    /// 전국이 다 보이는 상태인지입니다.
    ///
    /// false면 새로 채운 칸 하나만 확대해서 보여 주고,
    /// true로 바뀔 때 줌아웃하며 나머지 지역이 함께 나타납니다.
    let isRevealed: Bool

    init(
        highlightedRegionCode: String?,
        unlockedRegionCodes: Set<String> = [],
        isRevealed: Bool = true
    ) {
        self.highlightedRegionCode = highlightedRegionCode
        self.unlockedRegionCodes = unlockedRegionCodes
        self.isRevealed = isRevealed
    }

    var body: some View {
        GeometryReader { proxy in
            let camera = camera(in: proxy.size)

            ZStack {
                ForEach(PixelMapGeometryCache.tiles) { tile in
                    tileView(for: tile)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(camera.scale)
            .offset(camera.offset)
        }
        // 확대된 지도가 프레임 밖으로 넘치지 않게 합니다.
        .clipped()
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - 카메라

    private func camera(in size: CGSize) -> PixelMapCamera {
        guard !isRevealed,
              let highlightedRegionCode,
              let focused = PixelMapCamera.focused(
                  onRegionCode: highlightedRegionCode,
                  in: size
              )
        else { return .whole }

        return focused
    }

    // MARK: - 타일

    private func tileView(for tile: PixelMapTile) -> some View {
        let state = state(of: tile.region)

        return PixelTileShape(geometry: tile.geometry)
            .fill(state.fillColor, style: FillStyle(eoFill: true, antialiased: false))
            .overlay {
                AdministrativeBoundaryOutlineShape(geometry: tile.geometry)
                    .stroke(
                        state.strokeColor,
                        style: StrokeStyle(
                            lineWidth: state.strokeWidth,
                            lineCap: .square,
                            lineJoin: .miter
                        )
                    )
            }
            // 처음에는 새로 채운 칸만 보이고, 줌아웃하며 나머지가 드러납니다.
            .opacity(state == .highlighted || isRevealed ? 1 : 0)
            // 새로 채운 칸이 다른 칸에 가리지 않게 맨 위로 올립니다.
            .zIndex(state == .highlighted ? 1 : 0)
    }

    private func state(of region: AdministrativeRegion) -> TileState {
        if let highlightedRegionCode,
           region.containsAnyRegion(in: [highlightedRegionCode]) {
            return .highlighted
        }
        return region.containsAnyRegion(in: unlockedRegionCodes) ? .unlocked : .locked
    }

    private var accessibilityLabel: String {
        let unlockedCount = unlockedRegionCodes.union(
            highlightedRegionCode.map { [$0] } ?? []
        ).count
        return "픽셀맵. 채운 지역 \(unlockedCount)곳"
    }

    // MARK: - 색

    private enum TileState {
        /// 이번에 새로 채운 칸
        case highlighted
        /// 예전에 채운 칸
        case unlocked
        /// 아직 안 간 곳
        case locked

        var fillColor: Color {
            switch self {
            case .highlighted: PicselColor.actionGreen.opacity(0.45)
            case .unlocked: PicselColor.actionGreen.opacity(0.32)
            case .locked: PicselColor.pixelLockedFill
            }
        }

        var strokeColor: Color {
            switch self {
            case .highlighted: PicselColor.primaryGreen.opacity(0.9)
            case .unlocked: PicselColor.primaryGreen.opacity(0.45)
            case .locked: PicselColor.pixelLockedStroke
            }
        }

        var strokeWidth: CGFloat {
            self == .highlighted ? 0.9 : 0.45
        }
    }
}

/// AdministrativeRegionTile 안의 도형은 private이라 같은 지오메트리로 하나 더 둡니다.
private struct PixelTileShape: Shape {
    let geometry: AdministrativeRegionTileGeometry

    func path(in rect: CGRect) -> Path {
        geometry.fillPath(in: rect)
    }
}

#Preview("확대 상태") {
    PixelUnlockedMapView(
        highlightedRegionCode: "4711",
        unlockedRegionCodes: ["11", "50130"],
        isRevealed: false
    )
    .frame(height: 320)
    .padding()
}

#Preview("전국") {
    PixelUnlockedMapView(
        highlightedRegionCode: "4711",
        unlockedRegionCodes: ["11", "50130"],
        isRevealed: true
    )
    .frame(height: 320)
    .padding()
}
