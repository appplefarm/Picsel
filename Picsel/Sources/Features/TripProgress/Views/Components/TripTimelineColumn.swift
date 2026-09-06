//
//  TripTimelineColumn.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import SwiftUI

/// 카드 왼쪽의 진행 표시입니다. 초록 점과 점선으로 이어집니다.
struct TripTimelineColumn: View {

    /// 마지막 장소면 아래로 이어질 선을 그리지 않습니다.
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 점이 카드 상단보다 조금 아래에 놓이도록 시안의 간격을 둡니다.
            Spacer()
                .frame(height: Metric.dotTopOffset)

            Circle()
                .fill(PicselColor.actionGreen)
                .frame(width: Metric.dotSize, height: Metric.dotSize)

            if isLast {
                Spacer(minLength: 0)
            } else {
                VerticalDashedLine()
                    .stroke(
                        PicselColor.timelineLine,
                        style: StrokeStyle(
                            lineWidth: Metric.lineWidth,
                            lineCap: .round,
                            dash: Metric.dashPattern
                        )
                    )
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: Metric.dotSize)
        .accessibilityHidden(true)
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
