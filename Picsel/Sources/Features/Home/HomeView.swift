//
//  HomeView.swift
//  Picsel
//
//  Created by DS on 8/31/26.
//
import CoreLocation
import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var locationManager = CurrentLocationManager()
    @State private var confirmedDestination: PhotoDestination?
    @State private var photoExploreRequest: PhotoExploreRequest?
    @State private var isLocationAlertPresented = false
    @State private var isSettingsPresented = false
    @State private var isShowingManualSearch = false
    @State private var manualLocation: CLLocation?
    @State private var manualLocationName: String?

    private var hasValidOrigin: Bool {
        manualLocation != nil || locationManager.isLocationAuthorized
    }

    private var hasValidMapOrigin: Bool {
        manualLocation != nil || recommendationOrigin != nil
    }

    private var mapCoordinate: CLLocationCoordinate2D {
        if let manualLocation {
            return manualLocation.coordinate
        }
        return locationManager.currentLocation?.coordinate ?? viewModel.fallbackCoordinate
    }

    /// 여행 경로를 계산할 때 쓸 출발지입니다.
    ///
    /// 위치 권한을 거절하고 수동으로 입력한 경우, 그 값이 곧 이 사람의 현재 위치입니다.
    /// GPS를 끝내 받을 수 없으므로 수동 입력값을 그대로 출발지로 넘깁니다.
    private var tripOriginCoordinate: CLLocationCoordinate2D? {
        manualLocation?.coordinate ?? recommendationOrigin?.coordinate
    }

    /// 지도 표시용 기본 좌표를 실제 추천 기준 위치로 오인하지 않습니다.
    private var recommendationOrigin: CLLocation? {
        guard locationManager.isLocationAuthorized,
              let location = locationManager.currentLocation,
              location.horizontalAccuracy >= 0,
              CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
        return location
    }

    private var mapLocationName: String {
        if let manualLocationName {
            return "\(manualLocationName) (수동 지정)"
        }
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

                if hasValidOrigin {
                    radiusSlider
                        .padding(.horizontal, HomeStyle.horizontalPadding)
                        .padding(.top, 16)

                    destinationButton
                        .padding(.horizontal, HomeStyle.horizontalPadding)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                } else {
                    manualSearchBottomSection
                }
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
            if let trip = makeTrip(for: destination) {
                TransitSwipeView(
                    viewModel: TransitSwipeViewModel(
                        trip: trip,
                        destinationPhotoURL: destination.photoURL.flatMap(URL.init(string:))
                    ),
                    originCoordinate: tripOriginCoordinate
                )
            }
        }
        .sheet(isPresented: $isShowingManualSearch) {
            ManualLocationSearchView { location, name in
                manualLocation = location
                manualLocationName = name
                viewModel.updateMaximumRadius(from: location.coordinate)
            }
        }
        .navigationDestination(item: $photoExploreRequest) { request in
            let origin = request.originLocation

            PhotoExploreView(
                service: PhotoDestinationServiceFactory.make(
                    originLocation: origin,
                    selectedRadiusMeters: request.radiusMeters
                ),
                sourceNotice: PhotoDestinationServiceFactory.sourceNotice,
                originLocation: origin
            ) { destination in
                guard destination.canSelectAsDestination else { return }
                confirmedDestination = destination
            }
        }
        .alert(
            "현재 위치를 확인할 수 없어요",
            isPresented: $isLocationAlertPresented
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("현재 위치를 불러오지 못했어요. 잠시 후 다시 시도해주세요.")
        }
        .navigationDestination(isPresented: $isSettingsPresented) {
            SettingsView()
                .toolbar(.hidden, for: .tabBar)
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

            HomeSettingsButton {
                isSettingsPresented = true
            }
        }
    }
    

    private var mapSection: some View {
        ZStack(alignment: .topLeading) {
            NaverMapView(
                coordinate: mapCoordinate,
                radiusMeters: viewModel.currentRadiusMeters,
                isValidOrigin: hasValidMapOrigin
            )

            LinearGradient(
                stops: [
                    .init(color: PicselColor.homeBackground, location: 0),
                    .init(color: .clear, location: 0.10),
                    .init(color: .clear, location: 0.90),
                    .init(color: PicselColor.homeBackground, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            if hasValidOrigin {
                locationBadge
                    .padding(.leading, HomeStyle.horizontalPadding)
                    .padding(.top, 18)
            }
        }
        .clipped()
    }
    
    private var manualSearchBottomSection: some View {
        VStack(spacing: 24) {
            Button {
                isShowingManualSearch = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PicselColor.radiusGreen)
                    Text("어디에서 출발하시나요?")
                        .font(.callout)
                        .foregroundStyle(.gray)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .frame(height: 52)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            }
            .padding(.horizontal, HomeStyle.horizontalPadding)
            
            VStack(spacing: 8) {
                Text("현재 위치를 가져올 수 없어요 :(")
                Text("출발할 지역이나 장소를 직접 검색해주세요")
            }
            .font(.footnote)
            .foregroundColor(Color(red: 85/255, green: 135/255, blue: 110/255))
            .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.top, 60) // 그라데이션이 시작되는 곳으로부터 콘텐츠를 살짝 내림
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.0), Color(red: 168/255, green: 226/255, blue: 198/255).opacity(1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .padding(.top, -40) // 뷰 전체(배경 포함)를 맵 위로 끌어올림
    }

    private var locationBadge: some View {
        Button {
            if !locationManager.isLocationAuthorized {
                isShowingManualSearch = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(PicselColor.radiusGreen)

                Text("\(mapLocationName) · 반경 \(Int(viewModel.currentRadiusKm))km")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(PicselColor.homeText)
                    .contentTransition(.numericText())
                
                if !locationManager.isLocationAuthorized {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(.white, in: .capsule)
            .shadow(color: .black.opacity(0.14), radius: 4)
        }
        .disabled(locationManager.isLocationAuthorized)
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
        Button {
            guard let origin = manualLocation ?? recommendationOrigin else {
                locationManager.requestCurrentLocation()
                isLocationAlertPresented = true
                return
            }

            photoExploreRequest = PhotoExploreRequest(
                originLocation: origin,
                radiusMeters: max(
                    viewModel.currentRadiusMeters,
                    PhotoRecommendationPolicy.minimumRadiusMeters
                )
            )
        } label: {
            ZStack {
                // 텍스트는 ZStack의 기본 속성으로 버튼 정중앙에 위치
                VStack(spacing: 4) {
                    Text("사진으로 목적지 고르기")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("반경 안의 사진들을 둘러보세요")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }

                // 아이콘은 텍스트의 중앙 정렬에 영향을 주지 않고 좌측에 배치
                HStack {
                    Image(systemName: "photo")
                        .font(.title2)
                    Spacer()
                }
                .padding(.leading, 64)
            }
        }
        .buttonStyle(.primaryGradient)
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
        stop.photoURL = destination.photoURL
        stop.trip = trip
        trip.stops.append(stop)
        return trip
    }
}

/// 목적지 고르기 버튼을 누른 순간의 위치와 반경을 고정해 다음 화면에 전달합니다.
private struct PhotoExploreRequest: Hashable, Identifiable {
    let id = UUID()
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let radiusMeters: CLLocationDistance

    init(originLocation: CLLocation, radiusMeters: CLLocationDistance) {
        latitude = originLocation.coordinate.latitude
        longitude = originLocation.coordinate.longitude
        self.radiusMeters = radiusMeters
    }

    var originLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
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
