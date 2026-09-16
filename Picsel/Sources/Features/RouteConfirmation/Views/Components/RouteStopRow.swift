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
    let position: Position
    let showsTimeline: Bool

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
            if showsTimeline, let travelMinutes {
                // 첫 줄에 이동 시간이 있다는 것은 현재 위치에서 출발한다는 뜻입니다.
                // 캡슐에는 "N분"만 남으므로 출발점을 여기서 따로 밝혀 줍니다.
                if position.isFirst {
                    originRow
                }

                travelSegment(minutes: travelMinutes)
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

    private func travelSegment(minutes: Int) -> some View {
        HStack(spacing: Metric.timelineSpacing) {
            travelLabel(minutes: minutes)

            // 선 옆에 두던 시절의 자리를 비워, 카드가 밀리지 않게 합니다.
            Color.clear
                .frame(maxWidth: .infinity)
        }
        .frame(height: Metric.segmentHeight)
        .accessibilityLabel(
            position.isFirst
                ? "현재 위치에서 \(minutes)분 이동"
                : "직전 장소에서 \(minutes)분 이동"
        )
    }

    private var originRow: some View {
        HStack(spacing: Metric.timelineSpacing) {
            Circle()
                .stroke(PicselColor.actionGreen, lineWidth: 3)
                .frame(width: Metric.originDotSize, height: Metric.originDotSize)
                .frame(width: Metric.dotSize)

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
    private func travelLabel(minutes: Int) -> some View {
        ZStack {
            dashedLine
                .frame(width: Metric.dotSize)

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
        // 캡슐이 점 열보다 넓어도 카드 위치가 흔들리지 않도록 폭을 고정합니다.
        .frame(width: Metric.dotSize)
    }

    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            // 이동 시간 구간이 이미 위쪽 선을 그리므로 여기서는 아래로만 이어 줍니다.
            if position.isFirst {
                Color.clear.frame(maxHeight: .infinity)
            } else {
                dashedLine.frame(maxHeight: .infinity)
            }
            
            Circle()
                .fill(PicselColor.actionGreen)
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
        RemotePlacePhoto(url: thumbnailURL ?? stop.photoURL.flatMap(URL.init(string:)), compact: true)
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
    static let dotSize: CGFloat = 22
    /// 출발점은 아직 지나지 않은 곳이라 속을 비운 원으로 둡니다.
    static let originDotSize: CGFloat = 14
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
}

#if DEBUG
private enum RouteStopRowPreviewData {
    static func makeStops() -> [RouteStop] {
        let places: [(String, Double, Double, Bool)] = [
            ("호미곶 해맞이광장", 36.076_2, 129.567_3, false),
            ("구룡포 일본인가옥거리", 35.989_6, 129.554_9, false),
            ("이가리 닻 전망대", 36.187_992, 129.379_005, true)
        ]

        return places.enumerated().map { index, place in
            RouteStop(
                name: place.0,
                latitude: place.1,
                longitude: place.2,
                stopType: place.3 ? "destination" : "waypoint",
                orderIndex: index
            )
        }
    }

    static let minutes = [12, 8, 23]
}


#Preview {
    let stops = RouteStopRowPreviewData.makeStops()

    return VStack(spacing: 0) {
        ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
            RouteStopRow(
                stop: stop,
                thumbnailURL: nil,
                travelMinutes: RouteStopRowPreviewData.minutes[index],
                position: index == 0 ? .first : (index == stops.count - 1 ? .last : .middle),
                showsTimeline: true
            )
        }
    }
    .padding(24)
}

#endif
