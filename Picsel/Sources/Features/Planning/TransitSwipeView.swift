//
//  TransitSwipeView.swift
//  Picsel
//
//  Created by 김나영 on 8/31/26.
//


import SwiftUI

struct TransitSwipeView: View {
    @State var viewModel: TransitSwipeViewModel
    @State private var isShowingRouteConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 상단 헤더
            VStack(alignment: .leading, spacing: 8) {
                Text("경유지를 골라보세요")
                    .font(.largeTitle)
                    .bold()
                Text("목적지 부근에서 들르기 좋은 장소 10곳을 추천해드릴게요")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // MARK: - 카드 스택 영역
            ZStack {
                if viewModel.candidates.isEmpty && !viewModel.isLoading {
                    Text("모든 추천 장소를 확인했습니다.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(Array(viewModel.candidates.enumerated().reversed()), id: \.element.id) { index, place in
                        let angle = (index == 1) ? 3.0 : (index == 2) ? -2.0 : 0.0
                        let yOffset = CGFloat(index * 12)
                        
                        SwipeCardView(place: place) {
                            withAnimation(.spring()) { viewModel.swipeLeft(on: place) }
                        } onSwipeRight: {
                            withAnimation(.spring()) { viewModel.swipeRight(on: place) }
                        }
                        .rotationEffect(.degrees(index == 0 ? 0 : angle))
                        .offset(y: index == 0 ? 0 : yOffset)
                        .opacity(index < 3 ? 1 : 0)
                        .allowsHitTesting(index == 0)
                        .animation(.spring(), value: index)
                    }
                }
            }
            
            Spacer()
            
            // MARK: - 스와이프 안내 문구 및 버튼
            Text("왼쪽으로 넘기기 · 오른쪽으로 여행에 추가")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
            
            // MARK: - 하단 확정 바
            SwipeBottomBar(
                selectedCount: viewModel.selectedPlaces.count,
                onConfirm: {
                    viewModel.finalizeWaypoints()
                    isShowingRouteConfirmation = true
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $isShowingRouteConfirmation) {
            RouteConfirmationView(trip: viewModel.activeTrip)
                .toolbar(.hidden, for: .tabBar)
        }
        .onAppear {
            // 화면 진입 시 추천 장소 로드 (테스트용 더미 데이터 통신)
            Task {
//                await viewModel.fetchRecommendedPlaces(regionCode: 11111)
                await viewModel.fetchRecommendedPlaces(regionName: "포항")
            }
        }
    }
}
