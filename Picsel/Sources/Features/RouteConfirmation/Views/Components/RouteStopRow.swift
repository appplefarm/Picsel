//
//  RouteStopRow.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/31/26.
//  Created by kosoobin on 9/6/26.
//

import SwiftUI

/// 최종 경로 화면의 장소 한 줄입니다.
///
/// 이동 시간은 장소가 아니라 장소와 장소 "사이"의 값이라
/// 카드 안이 아닌 타임라인 선 옆에 둡니다.
struct RouteStopRow: View {
    let stop: RouteStop
    let thumbnailURL: URL?
    /// 직전 지점에서 이 장소까지 걸리는 시간입니다.
    let travelMinutes: Int?
    /// 이 장소가 경로에서 맡은 역할입니다. 점 모양을 지도 마커와 맞추는 데 씁니다.
    let kind: RouteMapMarker.Kind
    let position: Position
    /// 경로가 현재 위치에서 출발하는지 여부입니다.
    ///
    /// 예전에는 "첫 줄에 이동 시간이 있으면 현재 위치에서 출발하는 것"이라고 짐작했는데,
    /// 이동 시간은 못 받을 수도 있는 값이라 출발지 표시가 그때그때 사라졌습니다.
    /// 경로가 어디서 시작하는지는 화면이 짐작할 일이 아니라 전달받을 값입니다.
    let startsFromCurrentLocation: Bool
    let showsTimeline: Bool

    /// 이 줄 위에 출발지 표시를 그릴지 여부입니다. 첫 줄에서만 그립니다.
    private var showsOriginRow: Bool {
        startsFromCurrentLocation && position.isFirst
    }

    /// 이 줄의 점 위쪽으로 선을 이어야 하는지 여부입니다.
    ///
    /// 위에 무언가(출발지 표시 또는 앞 장소의 카드)가 있을 때만 잇습니다.
    /// 아무것도 없는데 이으면 선이 허공에 매달립니다.
    private var hasLineAboveDot: Bool {
        !position.isFirst || showsOriginRow
    }

    enum Position {
        case first
        case middle
        case last
        case only

        var isFirst: Bool { self == .first || self == .only }
        var isLast: Bool { self == .last || self == .only }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsTimeline {
                // 캡슐에는 "N분"만 남으므로 출발점이 어디인지 여기서 따로 밝혀 줍니다.
                if showsOriginRow {
                    originRow

                    // 출발지 행은 높이가 점 크기뿐이라 점 아래로 남는 여백이 11pt인데,
                    // 다음 카드 행은 점 위로 23pt가 남습니다. 그대로 두면 캡슐이
                    // 출발지 점 쪽으로 붙어 보입니다. 구간 높이를 키워도 위아래가 함께
                    // 늘어나 소용이 없으므로, 그 차이만큼 위를 선으로 채워 캡슐을 내립니다.
                    timelineFiller(height: Metric.lineAboveCard)
                }

                // 첫 줄은 출발지 표시가 있을 때만 위쪽 구간이 필요합니다.
                // 나머지 줄은 앞 장소의 카드가 이미 위에 있으므로, 캡슐을 놓을
                // 이동 시간이 있을 때만 자리를 벌립니다. 시간이 없으면 점선만으로 이어집니다.
                if showsOriginRow || (!position.isFirst && travelMinutes != nil) {
                    travelSegment(minutes: travelMinutes)
                }
            }

            HStack(spacing: Metric.timelineSpacing) {
                if showsTimeline {
                    timelineIndicator
                }

                card
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 타임라인

    /// 캡슐 없이 선만 잇는 빈 구간입니다. 간격을 맞추는 데만 씁니다.
    private func timelineFiller(height: CGFloat) -> some View {
        HStack(spacing: Metric.timelineSpacing) {
            dashedLine
                .frame(width: Metric.dotSize)

            Color.clear
                .frame(maxWidth: .infinity)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    /// 장소와 장소 사이 구간입니다. 이동 시간을 못 받았으면 점선만 그립니다.
    private func travelSegment(minutes: Int?) -> some View {
        HStack(spacing: Metric.timelineSpacing) {
            travelLabel(minutes: minutes)

            // 선 옆에 두던 시절의 자리를 비워, 카드가 밀리지 않게 합니다.
            Color.clear
                .frame(maxWidth: .infinity)
        }
        .frame(height: Metric.segmentHeight)
        .accessibilityLabel(travelAccessibilityLabel(minutes: minutes))
    }

    private func travelAccessibilityLabel(minutes: Int?) -> String {
        let from = showsOriginRow ? "현재 위치에서" : "직전 장소에서"
        guard let minutes else { return "\(from) 이동" }
        return "\(from) \(minutes)분 이동"
    }

    private var originRow: some View {
        HStack(spacing: Metric.timelineSpacing) {
            RouteStopDot(kind: .origin)
                .frame(width: Metric.dotSize, height: Metric.dotSize)

            Text("현재 위치")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PicselColor.locationLabel)

            Spacer(minLength: 0)
        }
        .accessibilityLabel("출발지, 현재 위치")
    }

    /// 이동 시간은 장소가 아니라 장소 "사이"의 값이라 점선 위에 얹습니다.
    ///
    /// 선 옆에 두면 숫자가 장소 이름과 같은 열에 놓여 형제처럼 보입니다.
    /// 선을 끊고 그 자리에 두면 "이 구간에 드는 시간"이라는 뜻이 형태로 드러납니다.
    private func travelLabel(minutes: Int?) -> some View {
        ZStack {
            dashedLine
                .frame(width: Metric.dotSize)

            if let minutes {
                Text("\(minutes)분")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PicselColor.travelMinutes)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, Metric.labelHorizontalPadding)
                .padding(.vertical, Metric.labelVerticalPadding)
                // 배경이 없으면 점선이 글자 사이를 관통해 읽기 어려워집니다.
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(PicselColor.rowBorder, lineWidth: 1)
                }
            }
        }
        // 캡슐이 점 열보다 넓어도 카드 위치가 흔들리지 않도록 폭을 고정합니다.
        .frame(width: Metric.dotSize)
    }

    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            // 위쪽 구간(출발지 · 이동 시간)이 그리는 선은 이 줄 바깥에서 끝납니다.
            // 카드 높이의 절반만큼은 이 줄 안에 남아 있어서, 여기서 잇지 않으면
            // 캡슐 아래부터 첫 점까지가 끊겨 보입니다.
            if hasLineAboveDot {
                dashedLine.frame(maxHeight: .infinity)
            } else {
                Color.clear.frame(maxHeight: .infinity)
            }
            
            RouteStopDot(kind: kind)
                // 점 크기는 역할마다 다르지만 열 너비는 고정해야 줄이 흔들리지 않습니다.
                .frame(width: Metric.dotSize, height: Metric.dotSize)

            if position.isLast {
                Color.clear.frame(maxHeight: .infinity)
            } else {
                dashedLine.frame(maxHeight: .infinity)
            }
        }
        .frame(width: Metric.dotSize)
        .accessibilityHidden(true)
    }

    private var dashedLine: some View {
        VerticalDashedLine()
            .stroke(
                PicselColor.timelineLine,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 6])
            )
    }

    // MARK: - 카드

    private var card: some View {
        HStack(spacing: Metric.cardContentSpacing) {
            thumbnail

            Text(stop.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PicselColor.subtitle)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(Metric.cardPadding)
        .background(PicselColor.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: Metric.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metric.cardCornerRadius, style: .continuous)
                .stroke(PicselColor.rowBorder, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: Metric.thumbnailCornerRadius, style: .continuous)
            .fill(Color(.systemGray5))
            .overlay {
                if let thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                        }
                    }
                }
            }
            .frame(width: Metric.thumbnailSize, height: Metric.thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: Metric.thumbnailCornerRadius, style: .continuous))
    }
}

/// 세로 점선 하나를 그리는 도형입니다.
private struct VerticalDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

/// 시안에서 가져온 값입니다.
private enum Metric {
    /// 점이 놓이는 열의 너비입니다. 점 자체의 크기는 역할에 따라 RouteMarkerStyle이 정합니다.
    static let dotSize: CGFloat = 22
    static let timelineSpacing: CGFloat = 12
    /// 이동 시간이 놓이는 구간 높이
    static let segmentHeight: CGFloat = 30
    static let labelHorizontalPadding: CGFloat = 7
    static let labelVerticalPadding: CGFloat = 3
    static let cardPadding: CGFloat = 10
    static let cardContentSpacing: CGFloat = 17
    static let cardCornerRadius: CGFloat = 18
    static let thumbnailSize: CGFloat = 48
    static let thumbnailCornerRadius: CGFloat = 10

    /// 카드 한 줄의 높이입니다. 썸네일이 가장 높아 그 값이 줄 높이를 정합니다.
    static var cardHeight: CGFloat { thumbnailSize + cardPadding * 2 }

    /// 카드 줄에서 점 위쪽으로 남는 선의 길이입니다.
    /// 썸네일이나 여백을 조정하면 이 값도 함께 따라갑니다.
    static var lineAboveCard: CGFloat { (cardHeight - dotSize) / 2 }
}

#if DEBUG
private enum RouteStopRowPreviewData {
    static func makeStops(count: Int) -> [RouteStop] {
        let places: [(String, Double, Double)] = [
            ("호미곶 해맞이광장", 36.076_2, 129.567_3),
            ("구룡포 일본인가옥거리", 35.989_6, 129.554_9),
            ("이가리 닻 전망대", 36.187_992, 129.379_005)
        ]

        return places.prefix(count).enumerated().map { index, place in
            RouteStop(
                name: place.0,
                latitude: place.1,
                longitude: place.2,
                stopType: index == count - 1 ? "destination" : "waypoint",
                orderIndex: index
            )
        }
    }

    static let minutes = [12, 8, 23]

    static func position(at index: Int, of count: Int) -> RouteStopRow.Position {
        switch (index, count) {
        case (_, 1): .only
        case (0, _): .first
        case (count - 1, _): .last
        default: .middle
        }
    }

    @ViewBuilder
    static func list(
        count: Int,
        startsFromCurrentLocation: Bool,
        travelMinutes: @escaping (Int) -> Int?
    ) -> some View {
        let stops = makeStops(count: count)

        VStack(spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                RouteStopRow(
                    stop: stop,
                    thumbnailURL: nil,
                    travelMinutes: travelMinutes(index),
                    kind: stop.isDestination
                        ? .destination
                        : (index == 0 && !startsFromCurrentLocation ? .origin : .waypoint),
                    position: position(at: index, of: count),
                    startsFromCurrentLocation: startsFromCurrentLocation,
                    showsTimeline: true
                )
            }
        }
        .padding(24)
    }
}

#Preview("현재 위치에서 출발") {
    RouteStopRowPreviewData.list(count: 3, startsFromCurrentLocation: true) { index in
        RouteStopRowPreviewData.minutes[index]
    }
}

#Preview("출발지 없음") {
    // 위치를 못 받아 첫 장소가 곧 출발지인 경우입니다.
    // 첫 점 위로는 이어질 것이 없으므로 선이 없어야 합니다.
    RouteStopRowPreviewData.list(count: 3, startsFromCurrentLocation: false) { index in
        index == 0 ? nil : RouteStopRowPreviewData.minutes[index]
    }
}

#Preview("장소 한 곳") {
    RouteStopRowPreviewData.list(count: 1, startsFromCurrentLocation: true) { _ in 43 }
}

#Preview("이동 시간 없음") {
    // 구간 시간을 못 받은 경우입니다. 캡슐만 빠지고 선은 이어져야 합니다.
    RouteStopRowPreviewData.list(count: 3, startsFromCurrentLocation: true) { _ in nil }
}
#endif
