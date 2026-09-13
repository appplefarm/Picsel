import SwiftUI

struct VisitedPlacesConfirmView: View {
    @State var viewModel: VisitedPlacesConfirmViewModel
    @State private var isShowingTripRecord = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 상단 헤더
            VStack(alignment: .leading, spacing: 8) {
                // TODO: 뷰모델의 Trip 데이터에서 지역명만 추출하는 로직 적용 가능
                Text("\(viewModel.trip.title)을 마칠까요?")
                    .font(.system(size: 24, weight: .bold))
                
                Text("다녀온 장소들을 확인하고 여정을 확정지어보세요")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Spacer()
            
            // MARK: - 카드 스택 영역
            ZStack {
                // 배열의 순서대로 카드를 렌더링. 마지막 요소가 뷰 계층의 맨 위에 위치함
                ForEach(Array(viewModel.displayStops.enumerated()), id: \.element.id) { index, stop in
                    let isTopCard = (index == viewModel.displayStops.count - 1)
                    
                    // reverseIndex: 맨 위 카드가 0, 그 아래가 1, 2...
                    let reverseIndex = viewModel.displayStops.count - 1 - index
                    
                    // 뒤에 있는 카드일수록 위로 올라가고 살짝 작아지는 시각적 효과 (피그마 반영)
                    let yOffset = CGFloat(reverseIndex) * -35.0
                    let scale = 1.0 - (CGFloat(reverseIndex) * 0.04)
                    
                    VisitedPlaceCardView(
                        stop: stop,
                        photoURL: viewModel.thumbnailURLsByStopID[stop.id],
                        isSelected: viewModel.isVisited(stopID: stop.id),
                        toggleSelection: {
                            viewModel.toggleVisited(for: stop.id)
                        },
                        onSwipeDown: {
                            viewModel.sendTopCardToBack()
                        }
                    )
                    .padding(.horizontal, 30)
                    .scaleEffect(scale, anchor: .bottom)
                    .offset(y: yOffset)
                    // 최상단 카드와 그 아래 2장(총 3장)까지만 보여줌
                    .opacity(reverseIndex < 3 ? 1 : 0)
                    // 맨 위에 있는 카드만 터치/스와이프 가능하도록 활성화
                    .allowsHitTesting(isTopCard)
                    .animation(.spring(), value: index) // 순서가 바뀔 때 자연스럽게 애니메이션
                }
            }
            .padding(.bottom, 30)
            
            // MARK: - 순서 안내 텍스트 (e.g. 2 / 10)
            if let topCard = viewModel.displayStops.last,
               let originalIndex = viewModel.trip.orderedStops.firstIndex(of: topCard) {
                Text("\(originalIndex + 1) / \(viewModel.trip.orderedStops.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }
            
            Spacer()
            
            // MARK: - 하단 완료 버튼
            VStack {
                Button {
                    viewModel.confirmVisitedPlaces()
                    isShowingTripRecord = true
                } label: {
                    Text("여행 완료하기")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        // TODO: 디자인 템플릿의 Primary Color 적용
                        .background(Color(red: 22/255, green: 140/255, blue: 90/255))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $isShowingTripRecord) {
            TripRecordView(trip: viewModel.trip)
                .toolbar(.hidden, for: .tabBar)
        }
    }
}
