//
//  RouteTimelineView.swift
//  Picsel
//
//  "다녀온 경로" — 왼쪽 점·선 + 오른쪽 장소 카드
//

import SwiftUI

struct RouteTimelineView: View {

    let stops: [RouteStopDisplay]

    var body: some View {
        VStack(spacing: 0) {
            // 마지막 줄인지 알아야 세로선을 끊을 수 있어서 index가 필요하다
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                RouteTimelineRow(stop: stop, isLast: index == stops.count - 1)
            }
        }
    }
}

/// 타임라인 한 줄 = 왼쪽 점/선 + 오른쪽 카드
struct RouteTimelineRow: View {

    let stop: RouteStopDisplay
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 왼쪽 점 + 선
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 12, height: 12)

                if !isLast {
                    // Rectangle은 유연해서 남는 높이를 알아서 채운다
                    Rectangle()
                        .fill(Color.gray.opacity(0.25))
                        .frame(width: 1)
                }
            }
            .frame(width: 12)
            .padding(.top, 20)

            // 오른쪽 카드
            VStack(alignment: .leading, spacing: 4) {
                Text(stop.name)
                    .font(.headline)

                if let minutes = stop.travelMinutesToNext {
                    Text("이동 +\(minutes)분")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.08))
            )
            .padding(.bottom, 12)
        }
    }
}

#Preview {
    RouteTimelineView(stops: RouteStopDisplay.mockStops)
        .padding()
}
