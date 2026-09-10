//
//  HomeView.swift
//  Picsel
//
//  Created by DS on 8/31/26.
//
import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var confirmedDestination: PhotoDestination?
    @State private var isSettingsPresented = false

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                headerSection
                    .frame(height: HomeStyle.headerHeight)
                    .padding(.horizontal, HomeStyle.horizontalPadding)
                    .padding(.bottom, 12)

                mapSection
                    .frame(maxWidth: .infinity)
                    .frame(height: HomeStyle.mapHeight(for: proxy.size.height))

                // 1차 배포는 반경 32km로 고정합니다. 반경 선택 재개 시 복원합니다.
                // radiusSlider
                //     .padding(.horizontal, HomeStyle.horizontalPadding)
                //     .padding(.top, 16)

                destinationButton
                    .padding(.horizontal, HomeStyle.horizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(PicselColor.homeBackground.ignoresSafeArea())
        .navigationDestination(item: $confirmedDestination) { destination in
            if let trip = makeTrip(for: destination) {
                TransitSwipeView(
                    viewModel: TransitSwipeViewModel(
                        trip: trip,
                        destinationPhotoURL: destination.photoURL.flatMap(URL.init(string:))
                    )
                )
            }
        }
    }

    private var headerSection: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("여행을 떠나기 좋은 날이에요")
                    .font(.callout)

                Text("어디로 떠나볼까요?")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .foregroundStyle(PicselColor.homeText)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            Button(action: {
                isSettingsPresented = true
            }) {
                Image(systemName: "gearshape")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .tint(PicselColor.homeText)
            .accessibilityLabel("설정")
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            SettingsView()
        }
    }
    

    private var mapSection: some View {
        ZStack(alignment: .topLeading) {
            GoogleMapView(
                coordinate: viewModel.mapCenterCoordinate,
                radiusMeters: viewModel.currentRadiusMeters
            )

            // Google 로고·저작권 표시가 있는 하단에는 배지나 그라데이션을 덮지 않습니다.
            locationBadge
                .padding(.leading, HomeStyle.horizontalPadding)
                .padding(.top, 10)
        }
        .clipped()
    }

    private var locationBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(PicselColor.radiusGreen)

            Text("\(viewModel.mapLocationName) · 반경 \(Int(viewModel.currentRadiusKm))km")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(PicselColor.homeText)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(.white, in: .capsule)
        .shadow(color: .black.opacity(0.14), radius: 4)
    }

    private var radiusSlider: some View {
        VStack(spacing: 2) {
            HStack(spacing: 12) {
                Image(systemName: "minus.magnifyingglass")

                Slider(value: $viewModel.radiusSliderPosition, in: 0...1)
                    .tint(PicselColor.radiusGreen)
                    .accessibilityValue("반경 \(Int(viewModel.currentRadiusKm))킬로미터")

                Image(systemName: "plus.magnifyingglass")
            }
            .foregroundStyle(PicselColor.sliderIcon)

            HStack {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(PicselColor.sliderTick)
                        .frame(width: 4, height: 4)
                    if index < 4 { Spacer() }
                }
            }
            .padding(.horizontal, 40)
        }
    }

    private var destinationButton: some View {
        NavigationLink {
            PhotoExploreView(
                service: PhotoDestinationServiceFactory.make(),
                sourceNotice: PhotoDestinationServiceFactory.sourceNotice
            ) { destination in
                guard destination.canSelectAsDestination else { return }
                confirmedDestination = destination
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "photo")
                    .font(.title2)

                VStack(spacing: 3) {
                    Text("사진으로 목적지 고르기")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("포항의 관광사진들을 둘러보세요")
                        .font(.caption)
                }
            }
            .foregroundStyle(PicselColor.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(PicselColor.homeCTA)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func makeTrip(for destination: PhotoDestination) -> Trip? {
        guard destination.canSelectAsDestination,
              let latitude = destination.latitude,
              let longitude = destination.longitude else { return nil }

        let trip = Trip(title: "\(destination.name) 여행")
        let stop = RouteStop(
            placeId: destination.id,
            name: destination.name,
            latitude: latitude,
            longitude: longitude,
            stopType: "destination",
            orderIndex: 0
        )
        stop.address = destination.address
        stop.regionCode = destination.regionCode
        stop.trip = trip
        trip.stops.append(stop)
        return trip
    }
}

private enum HomeStyle {
    static let horizontalPadding: CGFloat = 20
    static let headerHeight: CGFloat = 99
    static let preferredMapHeight: CGFloat = 458
    static let minimumMapHeight: CGFloat = 330
    static let controlsHeight: CGFloat = 155

    static func mapHeight(for availableHeight: CGFloat) -> CGFloat {
        min(preferredMapHeight, max(minimumMapHeight, availableHeight - headerHeight - controlsHeight))
    }
}

#Preview {
    HomeView()
}
