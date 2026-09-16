//
//  TripProgressView.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import SwiftData
import SwiftUI

/// 여행 진행 중 화면입니다.
/// 경로에 담긴 장소를 순서대로 보여 주고, 장소마다 선택한 내비 앱으로 길안내를 넘깁니다.
struct TripProgressView: View {

    let trip: Trip
    /// 전달된 사진 URL을 우선 사용하고, 재실행 후에는 RouteStop에 저장된 URL을 사용합니다.
    let thumbnailURLsByStopID: [UUID: URL]
    let onFinishTrip: () -> Void

    @AppStorage("preferredNavigationApp") private var navigationApp: NavigationApp = .kakaoMap
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingCancellation = false
    @State private var cancellationError: String?

    private var stops: [RouteStop] { trip.orderedStops }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                stopList

                cancellationButton
            }
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            finishButton
        }
        .alert("여행을 중단할까요?", isPresented: $isShowingCancellation) {
            Button("취소", role: .cancel) {}
            Button("여행 중단", role: .destructive, action: cancelTrip)
        } message: {
            Text("진행 중인 여행과 임시 사진 데이터가 삭제돼요. 여행 기록과 픽셀은 추가되지 않으며, 중단한 여행은 다시 이어갈 수 없어요.")
        }
        .alert("여행을 중단하지 못했어요", isPresented: Binding(
            get: { cancellationError != nil },
            set: { if !$0 { cancellationError = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(cancellationError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("여행 진행 중")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.black)

            Text("오늘도 특별한 대한민국을 만나보길 기대할게요")
                .font(.system(size: 13))
                .foregroundStyle(PicselColor.subtitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metric.headerHorizontalPadding)
        .padding(.vertical, 10)
        .padding(.bottom, 14)
    }

    private var stopList: some View {
        VStack(spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                HStack(alignment: .top, spacing: Metric.timelineSpacing) {
                    TripTimelineColumn(
                        isFirst: index == 0,
                        isLast: index == stops.count - 1
                    )

                    TripStopCard(
                        name: stop.name,
                        regionText: ShortAddress.make(from: stop.address),
                        photoURL: thumbnailURLsByStopID[stop.id] ?? stop.photoURL.flatMap(URL.init(string:)),
                        onNavigateTapped: { startNavigation(to: stop) },
                        tripID: trip.id
                    )
                    // 카드에만 간격을 주어야 행 높이가 늘어나고,
                    // 그래야 점선이 다음 카드 자리까지 내려옵니다.
                    .padding(.bottom, index == stops.count - 1 ? 0 : Metric.cardSpacing)
                }
            }
        }
        .padding(.leading, Metric.listLeadingPadding)
        .padding(.trailing, Metric.listTrailingPadding)
        .padding(.bottom, 24)
    }

    private var cancellationButton: some View {
        Button(role: .destructive) {
            isShowingCancellation = true
        } label: {
            Text("여행을 중단하시겠어요?")
                .font(PicselFont.label03)
                .underline()
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .accessibilityHint("여행을 삭제하고 홈으로 돌아가기 전 확인창을 엽니다")
    }

    private var finishButton: some View {
        Button(action: onFinishTrip) {
            Text("여행 마치기")
                .font(.system(size: 16, weight: .bold))
        }
        .buttonStyle(.primaryGradient)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.white)
    }

    private func startNavigation(to stop: RouteStop) {
        NavigationAppLauncher.open(
            navigationApp,
            to: NavigationDestination(
                name: stop.name,
                latitude: stop.latitude,
                longitude: stop.longitude
            )
        )
    }

    private func cancelTrip() {
        let tripID = trip.id
        do {
            try router.cancelTrip(tripID, in: modelContext)
            // 저장 성공 후에만 정리하며, 화면이 닫혀도 캐시 정리는 마저 수행합니다.
            Task { await TripImageStore.shared.removeTrip(tripID) }
        } catch {
            cancellationError = (error as? AppRouter.TripCancellationError)?.errorDescription
                ?? "여행 중단 상태를 저장하지 못했어요. 현재 여행은 유지되니 다시 시도해주세요."
        }
    }
}

/// 시안(402pt 프레임)에서 가져온 값입니다.
private enum Metric {
    static let headerHorizontalPadding: CGFloat = 16
    static let listLeadingPadding: CGFloat = 28
    static let listTrailingPadding: CGFloat = 39
    /// 타임라인 점과 카드 사이 간격
    static let timelineSpacing: CGFloat = 28
    /// 카드와 카드 사이 간격
    static let cardSpacing: CGFloat = 28
    static let finishButtonHeight: CGFloat = 66
}

#if DEBUG
private enum TripProgressPreviewData {
    static func make() -> (trip: Trip, thumbnails: [UUID: URL]) {
        let trip = Trip(title: "이가리 닻 전망대 여행")

        let places: [(name: String, address: String, latitude: Double, longitude: Double)] = [
            ("호미곶 해맞이광장", "경상북도 포항시 남구 호미곶면", 36.076_2, 129.567_3),
            ("구룡포 일본인가옥거리", "경상북도 포항시 남구 구룡포읍", 35.989_6, 129.554_9),
            ("월포해수욕장", "경상북도 포항시 북구 청하면", 36.157_8, 129.396_1),
            (
                DestinationCoordinateStore.ancharPointOfIgari.name,
                DestinationCoordinateStore.ancharPointOfIgari.address,
                DestinationCoordinateStore.ancharPointOfIgari.latitude,
                DestinationCoordinateStore.ancharPointOfIgari.longitude
            )
        ]

        let stops = places.enumerated().map { index, place in
            let stop = RouteStop(
                name: place.name,
                latitude: place.latitude,
                longitude: place.longitude,
                stopType: index == places.count - 1 ? "destination" : "waypoint",
                orderIndex: index
            )
            stop.address = place.address
            stop.trip = trip
            return stop
        }

        trip.stops = stops

        let thumbnails = Dictionary(
            uniqueKeysWithValues: stops.enumerated().compactMap { index, stop -> (UUID, URL)? in
                guard let url = URL(string: "https://picsum.photos/seed/picsel\(index)/600/400") else {
                    return nil
                }
                return (stop.id, url)
            }
        )

        return (trip, thumbnails)
    }
}

#Preview("여행 진행 중") {
    let data = TripProgressPreviewData.make()

    NavigationStack {
        TripProgressView(
            trip: data.trip,
            thumbnailURLsByStopID: data.thumbnails,
            onFinishTrip: {}
        )
    }
    .environment(AppRouter())
    .modelContainer(for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self], inMemory: true)
}
#endif
