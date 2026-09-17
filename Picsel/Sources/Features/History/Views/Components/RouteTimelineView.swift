//
//  RouteTimelineView.swift
//  Picsel
//
//  "그날의 여행" — 다녀온 장소를 점과 선으로 잇는 카드
//

import SwiftUI

struct RouteTimelineView: View {

    let stops: [RouteStopDisplay]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("그날의 여행")
                .font(PicselFont.label01)
                .foregroundStyle(PicselColor.textHelper)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                // 마지막 줄인지 알아야 세로선을 끊을 수 있어서 index가 필요합니다.
                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    RouteTimelineRow(
                        name: stop.name,
                        isLast: index == stops.count - 1
                    )
                }
            }
            // 점 기둥을 제목보다 살짝 안쪽으로 들여 씁니다.
            .padding(.leading, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(PicselColor.backgroundWarmWhite, in: .rect(cornerRadius: 20))
    }
}

/// 타임라인 한 줄 = 왼쪽 점·선 + 오른쪽 장소 이름
private struct RouteTimelineRow: View {

    let name: String
    let isLast: Bool

    /// 다음 줄과의 간격. 왼쪽 세로선이 이 간격까지 이어집니다.
    private let rowSpacing: CGFloat = 19

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(PicselColor.actionPrimaryBright)
                    .frame(width: 12, height: 12)
                    // 점 가운데가 장소 이름 첫 줄 가운데에 오도록 살짝 내립니다.
                    .padding(.top, 3)

                if !isLast {
                    // Rectangle은 남는 높이를 알아서 채워 다음 점까지 선을 잇습니다.
                    Rectangle()
                        .fill(PicselColor.actionPrimaryBright)
                        .frame(width: 2)
                }
            }
            .frame(width: 12)

            Text(name)
                .font(PicselFont.body01)
                .foregroundStyle(PicselColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, isLast ? 0 : rowSpacing)
        }
    }
}

#Preview {
    RouteTimelineView(stops: RouteStopDisplay.mockStops)
        .padding(24)
        .background(PicselColor.surface)
}
