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
                        
                        Text(stop.address ?? "주소 미상")
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
                    HStack(spacing: 4) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text("완료")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    // TODO: 기본색(회색) / 활성색(녹색) 디테일 컬러 적용
                    .background(isSelected ? Color(red: 47/255, green: 172/255, blue: 102/255) : Color.gray)
                    .clipShape(Capsule())
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
