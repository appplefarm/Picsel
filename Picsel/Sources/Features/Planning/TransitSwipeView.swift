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
    @State private var isShowingTripProgress = false
    @State private var isShowingTripRecord = false
    
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
            .padding(.bottom, 30) // 카드 스택과 텍스트 사이 간격 (기존 Spacer 대체)
            
            // MARK: - 스와이프 안내 문구 및 버튼
            let currentIndex = viewModel.totalFetchedCount - viewModel.candidates.count + 1
            let displayIndex = min(currentIndex, viewModel.totalFetchedCount)
            
            VStack(spacing: 16) {
                if viewModel.totalFetchedCount > 0 && !viewModel.candidates.isEmpty {
                    Text("\(Text("\(displayIndex)").font(.system(size: 15, weight: .bold))) / \(viewModel.totalFetchedCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 125/255, green: 160/255, blue: 142/255))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
                
                Text("왼쪽으로 넘기기 · 오른쪽으로 여행에 추가")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.42))
            }
            .padding(.bottom, 10)
            
            Spacer()
            
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
            RouteConfirmationView(
                trip: viewModel.activeTrip,
                thumbnailURLsByStopID: viewModel.thumbnailURLsByStopID
            ) { _ in
                isShowingTripProgress = true
            }
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $isShowingTripProgress) {
            TripProgressView(
                trip: viewModel.activeTrip,
                thumbnailURLsByStopID: viewModel.thumbnailURLsByStopID
            ) {
                isShowingTripRecord = true
            }
            .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(isPresented: $isShowingTripRecord) {
            TripRecordView()
                .toolbar(.hidden, for: .tabBar)
        }
        .onAppear {
            // 화면 진입 시 추천 장소 로드
            // TODO: 목적지 좌표에서 시군구를 판별해 지역을 자동으로 정합니다.
            //       RegionCodes.json은 포항시를 구 단위로 나누지 않으므로 북구·남구가 함께 조회됩니다.
            Task {
                if let pohang = RegionCodeManager.shared.findRegion(by: "포항시") {
                    await viewModel.fetchRecommendedPlaces(areaCode: pohang.areaCd, sigunguCode: pohang.sigunguCd)
                }
            }
        }
    }
}

#Preview {
    let dummyTrip = Trip(title: "포항 당일치기")
    let viewModel = TransitSwipeViewModel(trip: dummyTrip)
    
    // 더미 데이터 주입 (미리보기용)
    viewModel.candidates = [
        PlaceDTO(id: "1", name: "영일대 해수욕장", address: "경상북도 포항시 북구", latitude: 36.0, longitude: 129.0, photoURL: "https://tong.visitkorea.or.kr/cms/resource/66/2908766_image2_1.jpg", detailDescription: nil, regionCode: nil),
        PlaceDTO(id: "2", name: "호미곶 해맞이광장", address: "경상북도 포항시 남구", latitude: 36.1, longitude: 129.1, photoURL: "https://tong.visitkorea.or.kr/cms/resource/66/2908766_image2_1.jpg", detailDescription: nil, regionCode: nil),
        PlaceDTO(id: "3", name: "구룡포 일본인가옥거리", address: "경상북도 포항시 남구", latitude: 36.2, longitude: 129.2, photoURL: "https://tong.visitkorea.or.kr/cms/resource/66/2908766_image2_1.jpg", detailDescription: nil, regionCode: nil)
    ]
    viewModel.totalFetchedCount = 10
    
    return NavigationStack {
        TransitSwipeView(viewModel: viewModel)
    }
}
