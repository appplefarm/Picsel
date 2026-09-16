//
//  TransitSwipeView.swift
//  Picsel
//
//  Created by 김나영 on 8/31/26.
//


import CoreLocation
import SwiftData
import SwiftUI

struct TransitSwipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State var viewModel: TransitSwipeViewModel
    /// 홈에서 정한 출발지입니다. 수동으로 입력한 위치도 여기로 들어옵니다.
    let originCoordinate: CLLocationCoordinate2D?

    @State private var isShowingRouteConfirmation = false
    @State private var tripStartErrorMessage: String?
    @State private var showSwipeToast = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 상단 헤더
            VStack(alignment: .leading, spacing: 8) {
                Text("경유지를 골라보세요")
                    .font(.title)
                    .bold()
                Text("목적지 부근에서 들르기 좋은 장소를 최대 \(TransitSwipeViewModel.maximumRecommendationCount)곳 추천해드릴게요")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // MARK: - 카드 스택 영역
            ZStack {
                if viewModel.isLoading || !viewModel.hasLoadedRecommendations {
                    ProgressView()
                        .frame(width: 334, height: 239)
                } else if viewModel.candidates.isEmpty {
                    Text(
                        viewModel.totalFetchedCount == 0
                            ? "목적지 주변에서 추천할 장소를 찾지 못했어요."
                            : "모든 추천 장소를 확인했습니다."
                    )
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .frame(width: 334, height: 239) // 카드 사이즈와 동일한 빈 공간 유지 (하단 UI 고정용)
                } else {
                    ForEach(Array(viewModel.candidates.enumerated().reversed()), id: \.element.id) { index, place in
                        let angle = (index == 1) ? 6.0 : (index == 2) ? -4.5 : 0.0
                        
                        SwipeCardView(place: place, isTopCard: index == 0) {
                            withAnimation(.spring()) { viewModel.swipeLeft(on: place) }
                        } onSwipeRight: {
                            withAnimation(.spring()) { viewModel.swipeRight(on: place) }
                        }
                        .rotationEffect(.degrees(index == 0 ? 0 : angle))
                        .opacity(index < 3 ? 1 : 0)
                        .allowsHitTesting(index == 0)
                        .animation(.spring(), value: index)
                    }
                }
            }
            .padding(.bottom, 60) // 카드 스택과 텍스트 사이 간격 늘림
            
            // MARK: - 스와이프 안내 문구 및 버튼
            let currentIndex = viewModel.totalFetchedCount - viewModel.candidates.count + 1
            let displayIndex = min(currentIndex, viewModel.totalFetchedCount)
            
            HStack {
                Text("← 안 갈래요")
                    .onTapGesture { showToast() }
                
                Spacer()
                
                if viewModel.totalFetchedCount > 0 && !viewModel.candidates.isEmpty {
                    Text("\(Text("\(displayIndex)").font(.system(size: 15, weight: .bold))) / \(viewModel.totalFetchedCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 125/255, green: 160/255, blue: 142/255))
                }
                
                Spacer()
                
                Text("갈래요 →")
                    .onTapGesture { showToast() }
            }
            .padding(.horizontal, 32)
            .font(.system(size: 12))
            .foregroundColor(Color(white: 0.42))
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
                thumbnailURLsByStopID: viewModel.thumbnailURLsByStopID,
                originCoordinate: originCoordinate
            ) { _ in
                // 경로가 확정된 여행은 여기서 저장합니다.
                // 여행 시작 전 강제 종료 시에도 준비 홈으로 복원되도록 준비 상태 ID를 함께 저장합니다.
                if viewModel.saveTripPlan(in: modelContext) {
                    router.showTripReadyHome(for: viewModel.activeTrip)
                } else {
                    tripStartErrorMessage = "여행 계획을 저장하지 못했어요. 잠시 후 다시 시도해주세요."
                }
            }
                .toolbar(.hidden, for: .tabBar)
        }
        .alert(
            "여행 시작 실패",
            isPresented: Binding(
                get: { tripStartErrorMessage != nil },
                set: { if !$0 { tripStartErrorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(tripStartErrorMessage ?? "")
        }
        .overlay(
            VStack {
                if showSwipeToast {
                    Text("버튼 대신 화면을 좌우로 스와이프 해주세요")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 20)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                        .padding(.bottom, 120)
                        .transition(.opacity)
                }
            }
            , alignment: .bottom
        )
        .onAppear {
            // 경로 확인 화면에서 뒤로 오면 이 onAppear가 다시 돌면서 추천 목록을
            // 처음부터 받아옵니다. 고른 장소를 남겨 두면 그 위에 계속 쌓이므로
            // 목록과 선택을 함께 0곳으로 되돌립니다.
            viewModel.resetSelection()

            // 화면 진입 시 추천 장소 로드
            Task {
                // 목적지가 없거나 지역을 판별할 수 없으면 임의 지역을 추천하지 않습니다.
                guard let destination = viewModel.activeTrip.destinationStop else {
                    router.finishTripFlow(returningTo: .home)
                    return
                }

                let searchKeyword = destination.address ?? destination.name
                guard let region = RegionCodeManager.shared.findRegion(by: searchKeyword) else {
                    router.finishTripFlow(returningTo: .home)
                    return
                }

                await viewModel.fetchRecommendedPlaces(
                    areaCode: region.areaCd,
                    sigunguCode: region.sigunguCd
                )
            }
        }
    }
    
    private func showToast() {
        withAnimation {
            showSwipeToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSwipeToast = false
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
    viewModel.hasLoadedRecommendations = true
    
    return NavigationStack {
        TransitSwipeView(
            viewModel: viewModel,
            // 포항 시내를 출발지로 가정합니다.
            originCoordinate: CLLocationCoordinate2D(latitude: 36.019, longitude: 129.343)
        )
    }
}
