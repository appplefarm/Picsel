//
//  RouteStopRow.swift
//  Picsel
//

import SwiftUI

struct RouteStopRow: View {
    let stop: RouteStop
    let thumbnailURL: URL?
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
    }

    var body: some View {
        HStack(spacing: 12) {
            if showsTimeline {
                timelineIndicator
            }

            card
        }
        .frame(minHeight: 70)
        .accessibilityElement(children: .combine)
    }

    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(position.hasTopLine ? Color(.separator) : .clear)
                .frame(width: 1)

            Circle()
                .fill(Color(.systemGray5))
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

            VStack(alignment: .leading, spacing: 5) {
                Text(stop.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let travelMinutes {
                    Text("이동 +\(travelMinutes)분")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

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
