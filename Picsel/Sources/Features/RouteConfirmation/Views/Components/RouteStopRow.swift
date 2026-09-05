//
//  RouteStopRow.swift
//  Picsel
//

import SwiftUI

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

        var hasTopLine: Bool {
            self == .middle || self == .last
        }

        var hasBottomLine: Bool {
            self == .first || self == .middle
        }

        var isFirst: Bool {
            self == .first || self == .only
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 이동 시간은 장소가 아니라 장소와 장소 "사이"의 값이라
            // 카드 안이 아닌 타임라인 선 옆에 둡니다.
            if showsTimeline, let travelMinutes {
                travelSegment(minutes: travelMinutes)
            }

            HStack(spacing: 12) {
                if showsTimeline {
                    timelineIndicator
                }

                card
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func travelSegment(minutes: Int) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
                .frame(width: 20)

            Text(position.isFirst ? "현재 위치에서 \(minutes)분" : "\(minutes)분")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(height: 26)
        .accessibilityLabel(
            position.isFirst
                ? "현재 위치에서 \(minutes)분 이동"
                : "직전 장소에서 \(minutes)분 이동"
        )
    }

    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(position.hasTopLine ? Color(.separator) : .clear)
                .frame(width: 1)

            Circle()
                .fill(stop.isDestination ? Color.primary : Color(.systemGray5))
                .frame(width: 18, height: 18)

            Rectangle()
                .fill(position.hasBottomLine ? Color(.separator) : .clear)
                .frame(width: 1)
        }
        .frame(width: 20, height: 70)
        .accessibilityHidden(true)
    }

    private var card: some View {
        HStack(spacing: 12) {
            thumbnail

            Text(stop.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailURL {
            AsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    thumbnailPlaceholder
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            thumbnailPlaceholder
        }
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(.systemGray5))
            .frame(width: 48, height: 48)
    }
}
