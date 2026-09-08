//
//  TripProgressView.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import SwiftUI

/// 여행 진행 중 화면입니다.
/// 경로에 담긴 장소를 순서대로 보여 주고, 장소마다 선택한 내비 앱으로 길안내를 넘깁니다.
struct TripProgressView: View {

    let trip: Trip
    /// 경유지 사진입니다. RouteStop에 사진 필드가 없어 화면 사이로 전달받습니다.
    let thumbnailURLsByStopID: [UUID: URL]
    let onFinishTrip: () -> Void

    /// 온보딩이 붙기 전까지 이 화면의 토글로 정하는 값입니다.
    @AppStorage("preferredNavigationApp") private var navigationApp: NavigationApp = .naverMap

    private var stops: [RouteStop] { trip.orderedStops }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                NavigationAppPicker(selection: $navigationApp)
                    .padding(.horizontal, Metric.headerHorizontalPadding)
                    .padding(.bottom, 24)

                stopList
            }
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            finishButton
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
                        photoURL: thumbnailURLsByStopID[stop.id],
                        onNavigateTapped: { startNavigation(to: stop) }
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

    private var finishButton: some View {
        Button(action: onFinishTrip) {
            Text("여행 마치기")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PicselColor.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: Metric.finishButtonHeight)
                .background(PicselColor.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
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
}
#endif
