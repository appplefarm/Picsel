import SwiftUI

struct VisitedPlaceCardView: View {
    let stop: RouteStop
    let photoURL: URL?
    let isSelected: Bool
    let toggleSelection: () -> Void
    var onSwipeDown: () -> Void
    
    @State private var offset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단 썸네일 이미지
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                @unknown default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
            }
            .frame(height: 220)
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
        .offset(y: offset.height) // 드래그 시 Y축(아래)으로만 이동
        .gesture(
            DragGesture()
                .onChanged { value in
                    // 카드를 아래로 내릴 때만 움직이게
                    if value.translation.height > 0 {
                        offset = value.translation
                    }
                }
                .onEnded { value in
                    // 100 픽셀 이상 내렸을 때 스와이프 처리
                    if value.translation.height > 100 {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        onSwipeDown()
                        offset = .zero // 뷰모델이 배열을 업데이트하면 카드가 맨 뒤로 가므로 offset은 원상복구
                    } else {
                        // 되돌아가기
                        withAnimation(.spring()) {
                            offset = .zero
                        }
                    }
                }
        )
        .animation(.spring(), value: offset)
    }
}
