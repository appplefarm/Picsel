//
//  HomeView.swift
//  Picsel
//
//  Created by DS on 8/31/26.
//
import CoreLocation
import SwiftUI

struct HomeView: View {
    let onLogout: () -> Void
    @State private var viewModel = HomeViewModel()
    @State private var locationManager = CurrentLocationManager()
    @State private var confirmedDestination: PhotoDestination?
    @State private var isSettingsPresented = false

    private var mapCoordinate: CLLocationCoordinate2D {
        locationManager.currentLocation?.coordinate ?? viewModel.fallbackCoordinate
    }

    private var mapLocationName: String {
        if locationManager.currentLocation != nil {
            return locationManager.localityName
        }

        if locationManager.isLocationAuthorized {
            return "현재 위치 확인 중"
        }

        return "포항시 남구(기본 위치)"
    }

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

                radiusSlider
                    .padding(.horizontal, HomeStyle.horizontalPadding)
                    .padding(.top, 16)

                destinationButton
                    .padding(.horizontal, HomeStyle.horizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(PicselColor.homeBackground.ignoresSafeArea())
        .task {
            // 실제 위치를 받기 전에도 포항 기본 좌표에 맞는 범위를 보여줍니다.
            viewModel.updateMaximumRadius(from: mapCoordinate)
            locationManager.requestCurrentLocation()
        }
        .onChange(of: locationManager.currentLocation?.timestamp) { _, _ in
            guard let coordinate = locationManager.currentLocation?.coordinate else { return }
            viewModel.updateMaximumRadius(from: coordinate)
        }
        .navigationDestination(item: $confirmedDestination) { destination in
            TransitSwipeView(
                viewModel: TransitSwipeViewModel(
                    trip: makeTrip(for: destination),
                    destinationPhotoURL: destination.photoURL.flatMap(URL.init(string:))
                )
            )
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
            SettingsView(onLogout: onLogout)
        }
    }
    

    private var mapSection: some View {
        ZStack(alignment: .bottomLeading) {
            GoogleMapView(
                coordinate: mapCoordinate,
                radiusMeters: viewModel.currentRadiusMeters
            )

            LinearGradient(
                stops: [
                    .init(color: PicselColor.homeBackground, location: 0),
                    .init(color: .clear, location: 0.14),
                    .init(color: .clear, location: 0.82),
                    .init(color: PicselColor.homeBackground, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            locationBadge
                .padding(.leading, HomeStyle.horizontalPadding)
                .padding(.bottom, 10)
        }
        .clipped()
    }

    private var locationBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(PicselColor.radiusGreen)

            Text("\(mapLocationName) · 반경 \(Int(viewModel.currentRadiusKm))km")
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
                service: TourAPIPhotoDestinationService(configuration: .current)
            ) { destination in
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
                    Text("반경 안의 사진들을 둘러보세요")
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

    private func makeTrip(for destination: PhotoDestination) -> Trip {
        let trip = Trip(title: "\(destination.name) 여행")
        let destinationStop = makeDestinationStop(for: destination)

        destinationStop.trip = trip
        trip.stops.append(destinationStop)

        return trip
    }

    /// 수상작 API에 좌표가 없는 동안에는 DestinationCoordinateStore로 보강합니다.
    private func makeDestinationStop(for destination: PhotoDestination) -> RouteStop {
        if let place = destination.placeDTO {
            let stop = RouteStop(
                placeId: place.id,
                name: place.name,
                latitude: place.latitude,
                longitude: place.longitude,
                stopType: "destination",
                orderIndex: 0
            )
            stop.address = place.address
            stop.regionCode = place.regionCode
            return stop
        }

        let entry = DestinationCoordinateStore.entry(forContentID: destination.id)
        let stop = RouteStop(
            placeId: destination.id,
            name: destination.name,
            latitude: entry.latitude,
            longitude: entry.longitude,
            stopType: "destination",
            orderIndex: 0
        )
        stop.address = destination.address ?? entry.address
        stop.regionCode = destination.regionCode
        return stop
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
    HomeView(onLogout: { })
}
