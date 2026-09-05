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

    private var mapCoordinate: CLLocationCoordinate2D {
        locationManager.currentLocation?.coordinate ?? viewModel.fallbackCoordinate
    }

    var body: some View {
        ZStack {
            // MARK: - 1. Google Maps 레이어 (MapKit 대체)
                        GoogleMapView(
                            coordinate: mapCoordinate,
                            radiusMeters: viewModel.currentRadiusMeters
                        )
                        .ignoresSafeArea()
            
            // MARK: - 2. 상하단 그라데이션 페이드 오버레이
            VStack {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: .white.opacity(0.85), location: 0.6),
                        .init(color: .white.opacity(0.0), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
                
                Spacer()
                
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.0), location: 0.0),
                        .init(color: .white.opacity(0.85), location: 0.4),
                        .init(color: .white, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false) // 지도가 제스처를 받을 수 있도록 터치 통과

            // MARK: - 3. 상단 및 하단 UI 컨텐츠 레이어
            VStack(alignment: .leading, spacing: 0) {
                // 상단 타이틀 영역
                headerSection
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                
                Spacer()
                
                // 슬라이더 및 하단 액션 버튼
                bottomControlSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
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
                    trip: makeTrip(for: destination)
                )
            )
        }
    }

    // MARK: - 서브 뷰 컴포넌트

    // 상단 텍스트 헤더
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("이번엔 어디까지 떠나볼까요?")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("\(locationManager.localityName) · 반경 \(Int(viewModel.currentRadiusKm))km")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
        }
    }

    // 슬라이더 및 CTA 버튼
    private var bottomControlSection: some View {
        VStack(spacing: 20) {
            // 가까운 거리를 넓게 쓰는 로그 스케일, 1km 단위 실시간 슬라이더
            VStack(spacing: 8) {
                Slider(
                    value: $viewModel.radiusSliderPosition,
                    in: 0...1
                )
                .tint(Color(white: 0.2))
                .accessibilityValue("반경 \(Int(viewModel.currentRadiusKm))킬로미터")
                
                HStack {
                    ForEach(viewModel.radiusGuideValues, id: \.self) { radius in
                        Text(
                            radius == viewModel.radiusGuideValues.last
                                ? "최대 \(Int(radius))"
                                : "\(Int(radius))"
                        )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if radius != viewModel.radiusGuideValues.last {
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            // 사진으로 목적지 고르기 버튼
            NavigationLink {
                PhotoExploreView(
                    service: TourAPIPhotoDestinationService(
                        configuration: .current
                    )
                ) { destination in
                    confirmedDestination = destination
                }
            } label: {
                VStack(spacing: 4) {
                    Text("사진으로 목적지 고르기")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("반경 안의 목적지 사진을 둘러보세요")
                        .font(.caption)
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .background(Color(white: 0.2))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
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

#Preview {
    HomeView()
}
