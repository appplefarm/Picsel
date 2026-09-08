//
//  RouteConfirmationView.swift
//  Picsel
//

import SwiftUI
internal import _LocationEssentials

struct RouteConfirmationView: View {
    @State private var viewModel: RouteConfirmationViewModel
    @State private var editMode: EditMode
    @State private var locationManager = CurrentLocationManager()

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
            // 헤더와 경유지를 같은 섹션에 두면 순서 변경 시 위치 계산이 어긋나
            // 드래그가 되돌아가 버립니다. 섹션을 분리해 ForEach만 이동 대상이 되게 합니다.
            Section {
                headerSection
            }

            Section {
                ForEach(viewModel.routeStops) { stop in
                    RouteStopRow(
                        stop: stop,
                        thumbnailURL: viewModel.thumbnailURL(for: stop),
                        travelMinutes: viewModel.travelMinutes(before: stop),
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.white)
        .environment(\.editMode, $editMode)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !editMode.isEditing {
                startNavigationButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            // 권한 요청과 동시에, 위치가 없어도 우선 경로를 그려 둡니다.
            locationManager.requestCurrentLocation()
            await viewModel.loadDirections(origin: locationManager.currentLocation?.coordinate)
        }
        .onChange(of: locationManager.currentLocation?.timestamp) { _, _ in
            // 현재 위치가 도착하면 출발지를 반영해 다시 계산합니다.
            Task {
                await viewModel.loadDirections(origin: locationManager.currentLocation?.coordinate)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("최종 경로가 완성되었어요")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.black)

                Text("일정을 확인하고 편집을 이용해 자유롭게 수정해보세요")
                    .font(.system(size: 13))
                    .foregroundStyle(PicselColor.subtitle)
            }
            .padding(.vertical, 10)
            .padding(.bottom, 14)

            routeMap
                .aspectRatio(342 / 286, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 4) {
                Text(viewModel.routeSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(PicselColor.summaryText)

                // 내비 앱마다 값이 조금씩 다르므로 어림값임을 알려 줍니다.
                if let caption = viewModel.routeSummaryCaption {
                    Text(caption)
                        .font(.system(size: 11))
                        .foregroundStyle(PicselColor.summaryText.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 14)

            HStack {
                Spacer()

                Button(editMode.isEditing ? "완료" : "편집") {
                    toggleEditing()
                }
                .font(.system(size: 12))
                .foregroundStyle(PicselColor.editLabel)
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

    /// 좌표가 하나도 없으면 지도를 띄우는 대신 안내 자리를 보여줍니다.
    @ViewBuilder
    private var routeMap: some View {
        if viewModel.mapMarkers.isEmpty {
            RouteMapPlaceholderView()
        } else {
            RouteMapView(
                path: viewModel.mapPath,
                markers: viewModel.mapMarkers
            )
            .overlay {
                if viewModel.isCalculatingFirstRoute {
                    routeLoadingOverlay
                }
            }
        }
    }

    private var routeLoadingOverlay: some View {
        ZStack {
            Color.white.opacity(0.6)

            VStack(spacing: 8) {
                ProgressView()
                Text("경로를 계산하고 있어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("경로를 계산하고 있어요")
    }

    private var startNavigationButton: some View {
        Button {
            onStartNavigation(viewModel.activeTrip)
        } label: {
            Text("이대로 여행 계획표 만들기")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PicselColor.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 66)
                .background(PicselColor.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.white)
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
        travelMinutes: [UUID: Int],
        thumbnails: [UUID: URL]
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

        // 프리뷰에서 썸네일이 채워지는지 눈으로 확인하기 위한 임시 이미지입니다.
        // 실제 화면에서는 관광정보 API의 firstimage가 들어갑니다.
        let thumbnails = Dictionary(
            uniqueKeysWithValues: stops.enumerated().compactMap { index, stop -> (UUID, URL)? in
                guard let url = URL(string: "https://picsum.photos/seed/picsel\(index)/200") else {
                    return nil
                }
                return (stop.id, url)
            }
        )

        return (
            trip,
            Dictionary(uniqueKeysWithValues: zip(stops, minutes).map { ($0.id, $1) }),
            thumbnails
        )
    }
}

#Preview("최종 경로") {
    let data = RouteConfirmationPreviewData.make()

    NavigationStack {
        RouteConfirmationView(
            trip: data.trip,
            estimatedDurationMinutes: 230,
            thumbnailURLsByStopID: data.thumbnails,
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
            thumbnailURLsByStopID: data.thumbnails,
            travelMinutesByStopID: data.travelMinutes,
            initiallyEditing: true
        )
    }
}
#endif
