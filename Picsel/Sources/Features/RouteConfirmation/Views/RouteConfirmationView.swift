//
//  RouteConfirmationView.swift
//  Picsel
//

import SwiftUI

struct RouteConfirmationView: View {
    @State private var viewModel: RouteConfirmationViewModel
    @State private var editMode: EditMode

    private let onStartNavigation: (Trip) -> Void

    init(
        trip: Trip,
        estimatedDurationMinutes: Int? = nil,
        thumbnailURLsByStopID: [UUID: URL] = [:],
        travelMinutesByStopID: [UUID: Int] = [:],
        initiallyEditing: Bool = false,
        onStartNavigation: @escaping (Trip) -> Void = { _ in }
    ) {
        _viewModel = State(
            initialValue: RouteConfirmationViewModel(
                trip: trip,
                estimatedDurationMinutes: estimatedDurationMinutes,
                thumbnailURLsByStopID: thumbnailURLsByStopID,
                travelMinutesByStopID: travelMinutesByStopID
            )
        )
        _editMode = State(initialValue: initiallyEditing ? .active : .inactive)
        self.onStartNavigation = onStartNavigation
    }

    var body: some View {
        List {
            headerSection

            ForEach(viewModel.routeStops) { stop in
                RouteStopRow(
                    stop: stop,
                    thumbnailURL: viewModel.thumbnailURL(for: stop),
                    travelMinutes: viewModel.travelMinutes(for: stop),
                    position: position(for: stop),
                    showsTimeline: !editMode.isEditing
                )
                .listRowInsets(
                    EdgeInsets(
                        top: 4,
                        leading: editMode.isEditing ? 20 : 24,
                        bottom: 4,
                        trailing: 24
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .deleteDisabled(!editMode.isEditing)
                .moveDisabled(!editMode.isEditing)
            }
            .onDelete(perform: deleteStops)
            .onMove(perform: moveStops)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .environment(\.editMode, $editMode)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !editMode.isEditing {
                startNavigationButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: editMode)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("최종 경로가 완성됐어요")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.bottom, 24)

            RouteMapPlaceholderView()
                .aspectRatio(342 / 286, contentMode: .fit)

            Text(viewModel.routeSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 14)

            HStack {
                Spacer()

                Button(editMode.isEditing ? "완료" : "편집") {
                    toggleEditing()
                }
                .font(.subheadline)
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
                .accessibilityHint(
                    editMode.isEditing
                        ? "변경한 경유지 순서를 저장합니다"
                        : "경유지를 삭제하거나 순서를 변경합니다"
                )
            }
            .padding(.top, 12)
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 24, bottom: 6, trailing: 24))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var startNavigationButton: some View {
        Button {
            onStartNavigation(viewModel.activeTrip)
        } label: {
            Text("확인")
                .font(.headline)
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, 59)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .center
            )
        )
    }

    private func toggleEditing() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if editMode.isEditing {
                viewModel.commitEditing()
                editMode = .inactive
            } else {
                viewModel.beginEditing()
                editMode = .active
            }
        }
    }

    private func deleteStops(at offsets: IndexSet) {
        guard editMode.isEditing else { return }
        viewModel.removeStops(at: offsets)
    }

    private func moveStops(from offsets: IndexSet, to destination: Int) {
        guard editMode.isEditing else { return }
        viewModel.moveStops(from: offsets, to: destination)
    }

    private func position(for stop: RouteStop) -> RouteStopRow.Position {
        guard let index = viewModel.routeStops.firstIndex(where: { $0.id == stop.id }) else {
            return .only
        }

        switch (index, viewModel.routeStops.count) {
        case (_, 1):
            return .only
        case (0, _):
            return .first
        case (viewModel.routeStops.count - 1, _):
            return .last
        default:
            return .middle
        }
    }
}

#if DEBUG
private enum RouteConfirmationPreviewData {
    static func make() -> (
        trip: Trip,
        travelMinutes: [UUID: Int]
    ) {
        let trip = Trip(title: "이가리 닻 전망대 여행")
        trip.totalDistanceMeters = 124_000

        // 경유지는 국문 관광정보 API에서 받아오고, 마지막은 수상작 목적지입니다.
        let places: [(name: String, latitude: Double, longitude: Double)] = [
            ("호미곶 해맞이광장", 36.076_2, 129.567_3),
            ("구룡포 일본인가옥거리", 35.989_6, 129.554_9),
            ("월포해수욕장", 36.157_8, 129.396_1),
            (
                DestinationCoordinateStore.ancharPointOfIgari.name,
                DestinationCoordinateStore.ancharPointOfIgari.latitude,
                DestinationCoordinateStore.ancharPointOfIgari.longitude
            )
        ]
        let minutes = [12, 8, 15, 5]

        let stops = places.enumerated().map { index, place in
            RouteStop(
                name: place.name,
                latitude: place.latitude,
                longitude: place.longitude,
                stopType: index == places.count - 1 ? "destination" : "waypoint",
                orderIndex: index
            )
        }

        stops.forEach { $0.trip = trip }
        trip.stops = stops

        return (
            trip,
            Dictionary(uniqueKeysWithValues: zip(stops, minutes).map { ($0.id, $1) })
        )
    }
}

#Preview("최종 경로") {
    let data = RouteConfirmationPreviewData.make()

    NavigationStack {
        RouteConfirmationView(
            trip: data.trip,
            estimatedDurationMinutes: 230,
            travelMinutesByStopID: data.travelMinutes
        )
    }
}

#Preview("경로 편집") {
    let data = RouteConfirmationPreviewData.make()

    NavigationStack {
        RouteConfirmationView(
            trip: data.trip,
            estimatedDurationMinutes: 230,
            travelMinutesByStopID: data.travelMinutes,
            initiallyEditing: true
        )
    }
}
#endif
