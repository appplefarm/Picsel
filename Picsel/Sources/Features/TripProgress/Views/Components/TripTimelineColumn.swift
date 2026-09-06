//
//  TripTimelineColumn.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import SwiftUI

/// 카드 왼쪽의 진행 표시입니다. 초록 점과 점선으로 이어집니다.
///
/// 선은 점 위아래로 나눠 그립니다.
/// 위 구간이 없으면 카드와 카드 사이에서 선이 끊겨 보입니다.
struct TripTimelineColumn: View {

    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 점 위 구간: 첫 장소가 아니면 카드 상단부터 점까지 선을 잇습니다.
            if isFirst {
                Color.clear.frame(height: Metric.dotTopOffset)
            } else {
                dashedLine.frame(height: Metric.dotTopOffset)
            }

            Circle()
                .fill(PicselColor.actionGreen)
                .frame(width: Metric.dotSize, height: Metric.dotSize)

            // 점 아래 구간: 마지막 장소가 아니면 남은 높이를 모두 채웁니다.
            if isLast {
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
                style: StrokeStyle(
                    lineWidth: Metric.lineWidth,
                    lineCap: .round,
                    dash: Metric.dashPattern
                )
            )
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

private enum Metric {
    static let dotSize: CGFloat = 22
    static let dotTopOffset: CGFloat = 28
    static let lineWidth: CGFloat = 3
    static let dashPattern: [CGFloat] = [4, 6]
}
