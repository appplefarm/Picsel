import SwiftUI

struct VisitedPlaceCardView: View {
    let stop: RouteStop
    let photoURL: URL?
    let isSelected: Bool
    let toggleSelection: () -> Void
    var onSwipeDown: () -> Void
    var onSwipeUp: () -> Void
    
    @State private var offset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단 썸네일 이미지
            RemotePlacePhoto(
                url: photoURL ?? stop.photoURL.flatMap(URL.init(string:)),
                tripID: stop.trip?.id
            )
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .contentShape(Rectangle())
            .clipped()
            // 미완료(비활성화) 시 사진 흑백 처리
            .grayscale(isSelected ? 0.0 : 1.0)
            
            // 하단 텍스트 및 토글 버튼 영역
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(stop.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 47/255, green: 172/255, blue: 102/255))
                        
                        Text(ShortAddress.make(from: stop.address) ?? "주소 미상")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 47/255, green: 172/255, blue: 102/255))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 완료 토글 버튼
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    toggleSelection()
                }) {
                    Text("완료")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Color(white: 0.7))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color(red: 47/255, green: 172/255, blue: 102/255) : Color.white)
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : Color(white: 0.8), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .offset(y: offset.height) // 드래그 시 Y축으로만 이동
        // 드래그 거리가 100px에 가까워질수록 카드가 서서히 투명해짐
        .opacity(max(1.0 - Double(abs(offset.height)) / 120.0, 0.0))
        .gesture(
            DragGesture()
                .onChanged { value in
                    // 한계치를 넘어가면 드래그 저항력(고무줄 효과)을 주어 카드가 너무 위/아래로 끝없이 끌려가지 않도록 함
                    var dragY = value.translation.height
                    let limit: CGFloat = 80
                    
                    if dragY > limit {
                        dragY = limit + (dragY - limit) * 0.3
                    } else if dragY < -limit {
                        dragY = -limit + (dragY + limit) * 0.3
                    }
                    
                    offset = CGSize(width: 0, height: dragY)
                }
                .onEnded { value in
                    if value.translation.height > 80 {
                        // 아래로 내렸을 때 (다음 카드 보기 - 현재 카드를 뒤로)
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        onSwipeDown()
                        offset = .zero
                    } else if value.translation.height < -80 {
                        // 위로 올렸을 때 (이전 카드 보기 - 뒤에 있던 카드를 앞으로)
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        onSwipeUp()
                        offset = .zero
                    } else {
                        // 스와이프 임계치를 넘지 못해 취소될 때
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = .zero
                        }
                    }
                }
        )
    }
}
