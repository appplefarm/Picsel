//
//  RouteConfirmationView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/31/26.
//

import CoreLocation
import SwiftUI
internal import _LocationEssentials

struct RouteConfirmationView: View {
    @State private var viewModel: RouteConfirmationViewModel
    @State private var editMode: EditMode
    @State private var locationManager = CurrentLocationManager()
    @Environment(\.dismiss) private var dismiss
    /// 프리뷰에는 라우터가 없으므로 옵셔널로 받습니다. 없으면 화면을 닫는 것으로 대신합니다.
    @Environment(AppRouter.self) private var router: AppRouter?
    @State private var isEmptyRouteAlertPresented = false
    @State private var retryAttempt = 0
    @State private var mapReloadID = 0

    /// 앞 화면에서 정해 준 출발지입니다.
    ///
    /// 위치 권한을 거절하고 수동으로 입력한 경우, 이 값이 그 사람의 현재 위치입니다.
    /// 이때 GPS는 끝내 오지 않으므로 여기서 받지 못하면 출발지가 아예 사라집니다.
    private let originCoordinate: CLLocationCoordinate2D?

    private let onStartNavigation: (Trip) -> Void

    init(
        trip: Trip,
        estimatedDurationMinutes: Int? = nil,
        thumbnailURLsByStopID: [UUID: URL] = [:],
        travelMinutesByStopID: [UUID: Int] = [:],
        originCoordinate: CLLocationCoordinate2D? = nil,
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
        self.originCoordinate = originCoordinate
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
                        kind: viewModel.stopKind(for: stop),
                        position: position(for: stop),
                        startsFromCurrentLocation: viewModel.startsFromCurrentLocation,
                        showsTimeline: !editMode.isEditing
                    )
                    .listRowInsets(
                        EdgeInsets(
                            top: 0,
                            leading: editMode.isEditing ? 20 : 24,
                            bottom: 0,
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
                .padding(.top, 4)
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
        .onAppear {
            // 앞 화면에서 수동 출발지를 받았으면 권한을 다시 물을 이유가 없습니다.
            if originCoordinate == nil {
                locationManager.requestCurrentLocation()
            }
        }
        .task(id: RouteRequestID(timestamp: originCoordinate == nil ? locationManager.currentLocation?.timestamp : nil, attempt: retryAttempt)) {
            await viewModel.loadDirections(origin: resolvedOrigin)
        }
        .onDisappear { viewModel.cancelDirections() }
        .alert("장소를 모두 지웠어요", isPresented: $isEmptyRouteAlertPresented) {
            Button("홈으로 돌아가기", role: .destructive) { leaveTripFlow() }
            Button("취소", role: .cancel) { viewModel.undoEmptyingRemoval() }
        } message: {
            Text("경로에 남은 장소가 없어요.\n홈으로 돌아가면 지금 고른 여행은 사라집니다.")
        }
        .onNetworkRecovery {
            // SDK의 지도 타일과 경로 API는 별개입니다. 연결 복구 시 지도만 별도로 다시 만듭니다.
            mapReloadID = NetworkRecovery.shared.generation
            if viewModel.directionsFailure?.retriesOnReconnect == true {
                retryAttempt += 1
            }
        }
    }

    /// 실제로 경로 계산에 쓸 출발지입니다.
    ///
    /// 앞 화면이 정해 준 값을 먼저 씁니다. 홈에서 이미 "수동 입력 > GPS" 순서로 고른 값이라
    /// 여기서 GPS를 다시 우선하면 두 화면의 출발지가 달라집니다.
    private var resolvedOrigin: CLLocationCoordinate2D? {
        originCoordinate ?? locationManager.currentLocation?.coordinate
    }

    private struct RouteRequestID: Equatable {
        let timestamp: Date?
        let attempt: Int
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.isRouteEmpty ? "경로에 남은 장소가 없어요" : "최종 경로가 완성되었어요")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.black)

                Text(
                    viewModel.isRouteEmpty
                        ? "장소를 다시 골라야 여행 계획표를 만들 수 있어요"
                        : "일정을 확인하고 편집을 이용해 자유롭게 수정해보세요"
                )
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

            if let failure = viewModel.directionsFailure {
                RequestFailureView(failure: failure) { retryAttempt += 1 }
                    .frame(maxWidth: .infinity)
            }

            HStack {
                Spacer()

                // 편집 중에는 빠져나갈 길이 있어야 하므로 "완료"는 항상 둡니다.
                // 다만 남은 장소가 없을 때 "편집"은 누를 이유가 없어 감춥니다.
                if editMode.isEditing || !viewModel.isRouteEmpty {
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
            .id(mapReloadID)
            .overlay {
                if NetworkRecovery.shared.isConnected == false {
                    Text("인터넷 연결이 없어 지도가 일부 표시되지 않을 수 있어요.")
                        .font(.caption)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding()
                } else if viewModel.isCalculatingFirstRoute {
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

    /// 빈 경로에서는 계획표를 만들 수 없으므로, 버튼이 다시 고르러 가는 길이 됩니다.
    ///
    /// 비활성화만 하면 사용자가 아무것도 할 수 없는 화면에 갇힙니다.
    /// 여기서 할 수 있는 유일한 일이 "장소 다시 고르기"라면 그것을 버튼으로 둡니다.
    private var startNavigationButton: some View {
        Button {
            if viewModel.isRouteEmpty {
                dismiss()
            } else {
                onStartNavigation(viewModel.activeTrip)
            }
        } label: {
            Text(viewModel.isRouteEmpty ? "장소 다시 고르기" : "이대로 여행 계획표 만들기")
                .font(.system(size: 16, weight: .bold))
        }
        .buttonStyle(.primaryGradient)
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

        // 빈 화면에 도착한 뒤에 설명하는 것보다, 마지막 하나가 사라지는 순간에
        // 되돌릴 기회를 주는 편이 낫습니다.
        if viewModel.isRouteEmpty {
            isEmptyRouteAlertPresented = true
        }
    }

    /// 여행 만들기를 그만두고 홈 첫 화면으로 돌아갑니다.
    private func leaveTripFlow() {
        guard let router else {
            // 라우터가 없는 환경(프리뷰 등)에서는 최소한 이 화면은 빠져나갑니다.
            dismiss()
            return
        }
        router.finishTripFlow(returningTo: .home)
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

    /// 편집에서 장소를 모두 지운 여행입니다.
    ///
    /// 거리 값을 일부러 넣어 둡니다. 장소가 없는데도 지난 경로의 숫자가
    /// 요약에 새어 나오지 않는지 확인하는 것이 이 프리뷰의 목적입니다.
    static func makeEmpty() -> Trip {
        let trip = Trip(title: "빈 여행")
        trip.totalDistanceMeters = 124_000
        return trip
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

#Preview("모든 장소 삭제") {
    NavigationStack {
        RouteConfirmationView(
            trip: RouteConfirmationPreviewData.makeEmpty(),
            estimatedDurationMinutes: 230
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
