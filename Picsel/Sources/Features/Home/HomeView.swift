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
    @State private var selectedTab: Int = 0

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
                    .padding(.bottom, 8)

                // TODO: 탭바 수정 - 바닐라 TabView
                // 커스텀 플로팅 탭바
                customFloatingTabBar
                    .padding(.bottom, 8)
            }
        }
        .task {
            locationManager.requestCurrentLocation()
        }
    }

    // MARK: - 서브 뷰 컴포넌트

    // 상단 텍스트 헤더
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("여행을 떠나기 좋은 날이에요 \(viewModel.userName)님,")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
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
            // 0~150km, 1km 단위 실시간 슬라이더
            VStack(spacing: 8) {
                Slider(
                    value: $viewModel.currentRadiusKm,
                    in: viewModel.radiusRange,
                    step: 1
                )
                .tint(Color(white: 0.2))
                
                HStack {
                    ForEach(viewModel.radiusGuideValues, id: \.self) { radius in
                        Text("\(Int(radius))")
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
            Button {
                // 탐색 플로우 진입 액션
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
        }
    }

    // TODO: 탭바 수정 후 삭제
    // 하단 커스텀 탭바
    private var customFloatingTabBar: some View {
        HStack(spacing: 36) {
            tabItem(title: "홈", icon: "house.fill", tag: 0)
            tabItem(title: "픽셀맵", icon: "mappin.and.ellipse", tag: 1)
            tabItem(title: "히스토리", icon: "newspaper", tag: 2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(UIColor.secondarySystemBackground).opacity(0.95))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    private func tabItem(title: String, icon: String, tag: Int) -> some View {
        Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 11, weight: selectedTab == tag ? .bold : .regular))
            }
            .foregroundStyle(selectedTab == tag ? .primary : .secondary)
            .frame(width: 48)
        }
    }
}

#Preview {
    HomeView()
}
