import SwiftUI

struct VisitedPlacesConfirmView: View {
    @State var viewModel: VisitedPlacesConfirmViewModel
    @State private var isShowingTripRecord = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 상단 헤더 (요약 타이틀)
            VStack(alignment: .leading, spacing: 8) {
                Text("여행을 마치시겠어요?")
                    .font(.system(size: 24, weight: .bold))
                
                Text("방문하지 않은 장소는 체크 해제해주세요.")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // MARK: - 방문 장소 리스트
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.stops) { stop in
                        VisitedPlaceRow(
                            stop: stop,
                            photoURL: viewModel.thumbnailURLsByStopID[stop.id],
                            isSelected: viewModel.isVisited(stopID: stop.id),
                            toggleSelection: {
                                // 상태 토글 시 햅틱 피드백
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.toggleVisited(for: stop.id)
                            }
                        )
                        
                        Divider()
                            .padding(.leading, 88) // 썸네일 이후부터 라인 그리기
                    }
                }
                .padding(.top, 8)
            }
            
            // MARK: - 하단 완료 버튼
            VStack {
                Button {
                    // 실제 모델 데이터(RouteStop)에 최종 isVisited 값 덮어쓰기
                    viewModel.confirmVisitedPlaces()
                    // 다음 화면(기록 뷰)으로 이동
                    isShowingTripRecord = true
                } label: {
                    Text("\(viewModel.visitedStopIDs.count)곳의 장소로 여행 기록하기")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        // TODO: 디자인 템플릿의 Primary Color로 변경 가능
                        .background(viewModel.visitedStopIDs.isEmpty ? Color.gray : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(viewModel.visitedStopIDs.isEmpty) // 아무 곳도 안 갔다면 기록 불가
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(Color.white)
            .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
        }
        .navigationBarTitleDisplayMode(.inline)
        // 기존 진행 화면에서 쓰던 숨김 처리 유지
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $isShowingTripRecord) {
            TripRecordView(trip: viewModel.trip)
                .toolbar(.hidden, for: .tabBar)
        }
    }
}
