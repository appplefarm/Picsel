//
//  SwipeCardView.swift
//  Picsel
//
//  Created by 김나영 on 8/31/26.
//


import SwiftUI

struct SwipeCardView: View {
    let place: PlaceDTO
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void
    
    // 제스처에 따른 카드 이동 상태
    @State private var offset: CGSize = .zero
    @State private var hasTriggeredHaptic: Bool = false
    
    var body: some View {
        ZStack {
//            RoundedRectangle(cornerRadius: 20)
//                .fill(.gray)
            AsyncImage(url: URL(string: place.photoURL ?? "")) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.gray)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.gray.opacity(0.3)
                @unknown default:
                    Color.gray.opacity(0.3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(10)
            .clipped()
            
            VStack {
                Spacer()
                Text(place.name)
                    .font(.title2)
                    .bold()
                    .padding()
                    .frame(maxWidth: .infinity)
//                    .background(Color.white.opacity(0.8))
            }
            // MARK: - 스와이프 방향에 따른 시각적 피드백 (오버레이 및 아이콘)
            ZStack {
                // 오른쪽 스와이프 (초록색 그라데이션 - 오른쪽 가장자리)
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.5),
                        .init(color: .green, location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(Double(max(0, offset.width) / 150) * 0.8)
                
                // 왼쪽 스와이프 (빨간색 그라데이션 - 왼쪽 가장자리)
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .red, location: 0.0),
                        .init(color: .clear, location: 0.5)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(Double(max(0, -offset.width) / 150) * 0.8)
                
                HStack {
                    // 왼쪽 X 아이콘
                    Image(systemName: "xmark.circle")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                        .opacity(Double(max(0, -offset.width) / 100))
                        .padding(.leading, 30)
                    
                    Spacer()
                    
                    // 오른쪽 O 아이콘
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.green)
                        .background(Circle().fill(Color.white))
                        .opacity(Double(max(0, offset.width) / 100))
                        .padding(.trailing, 30)
                }
            }
            .cornerRadius(10) // 사진 밖으로 삐져나가지 않도록 마스크 처리
        }
        .frame(width: 334, height: 239) // 피그마 가로형 디자인 고정 사이즈로 복구 (레이아웃 붕괴 방지)
        // 1. 드래그 거리에 따른 위치 이동 및 약간의 회전 효과 (자연스러움 추가)
        .offset(x: offset.width, y: offset.height * 0.4)
        .rotationEffect(.degrees(Double(offset.width / 10)))
        .shadow(radius: 5) // 사방으로 번지던 색상 그림자 제거, 기본 그림자만 유지
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                }
                .onEnded { _ in
                    handleSwipe()
                }
        )
        // 카드가 100px(임계값)을 넘길 때 달칵거리는 햅틱 피드백 발생
        .onChange(of: offset.width) { newValue in
            let threshold: CGFloat = 100
            if abs(newValue) >= threshold && !hasTriggeredHaptic {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                hasTriggeredHaptic = true
            } else if abs(newValue) < threshold {
                hasTriggeredHaptic = false
            }
        }
        .animation(.spring(), value: offset) // 손을 놓았을 때 부드러운 애니메이션
    }
    
    // MARK: - 계산된 그림자 색상
    private var shadowColor: Color {
        let opacity = min(abs(offset.width) / 150, 1.0)
        if offset.width > 0 {
            return Color.green.opacity(opacity * 0.8)
        } else if offset.width < 0 {
            return Color.red.opacity(opacity * 0.8)
        }
        return Color.black.opacity(0.15)
    }
    
    // 2. 스와이프 임계값(Threshold) 계산 로직
    private func handleSwipe() {
        let swipeThreshold: CGFloat = 100 // 100픽셀 이상 움직이면 스와이프 판정
        
        if offset.width > swipeThreshold {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onSwipeRight()
        } else if offset.width < -swipeThreshold {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onSwipeLeft()
        } else {
            // 임계값을 못 넘기면 원위치로 복귀
            offset = .zero
        }
    }
}

#Preview {
    SwipeCardView(
        place: PlaceDTO(
            id: "1",
            name: "샘플 관광지",
            address: "경상북도 포항시 남구",
            latitude: 36.0,
            longitude: 129.0,
            photoURL: "https://tong.visitkorea.or.kr/cms/resource/66/2908766_image2_1.jpg",
            detailDescription: nil,
            regionCode: nil
        ),
        onSwipeLeft: { print("Left Swipe") },
        onSwipeRight: { print("Right Swipe") }
    )
}
