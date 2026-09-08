//
//  RouteStopRow.swift
//  Picsel
//
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
            dashedLine
                .frame(width: Metric.dotSize)

            Text(position.isFirst ? "현재 위치에서 \(minutes)분" : "\(minutes)분")
                .font(.system(size: 11))
                .foregroundStyle(PicselColor.travelMinutes)
        }
        .frame(height: Metric.segmentHeight)
        .accessibilityLabel(
            position.isFirst
                ? "현재 위치에서 \(minutes)분 이동"
                : "직전 장소에서 \(minutes)분 이동"
        )
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
    static let dotSize: CGFloat = 22
    static let timelineSpacing: CGFloat = 12
    /// 이동 시간이 놓이는 구간 높이
    static let segmentHeight: CGFloat = 26
    static let cardPadding: CGFloat = 10
    static let cardContentSpacing: CGFloat = 17
    static let cardCornerRadius: CGFloat = 18
    static let thumbnailSize: CGFloat = 48
    static let thumbnailCornerRadius: CGFloat = 10
}
