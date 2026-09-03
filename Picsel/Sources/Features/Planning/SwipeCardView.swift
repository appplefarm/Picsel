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
            .frame(width: 320, height: 420)
            .cornerRadius(20)
            .clipped()
            .shadow(radius: 5)
            
            VStack {
                Spacer()
                Text(place.name)
                    .font(.title2)
                    .bold()
                    .padding()
                    .frame(maxWidth: .infinity)
//                    .background(Color.white.opacity(0.8))
            }
        }
        .frame(width: 320, height: 420)
        // 1. 드래그 거리에 따른 위치 이동 및 약간의 회전 효과 (자연스러움 추가)
        .offset(x: offset.width, y: offset.height * 0.4)
        .rotationEffect(.degrees(Double(offset.width / 10)))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                }
                .onEnded { _ in
                    handleSwipe()
                }
        )
        .animation(.spring(), value: offset) // 손을 놓았을 때 부드러운 애니메이션
    }
    
    // 2. 스와이프 임계값(Threshold) 계산 로직
    private func handleSwipe() {
        let swipeThreshold: CGFloat = 100 // 100픽셀 이상 움직이면 스와이프 판정
        
        if offset.width > swipeThreshold {
            onSwipeRight()
        } else if offset.width < -swipeThreshold {
            onSwipeLeft()
        } else {
            // 임계값을 못 넘기면 원위치로 복귀
            offset = .zero
        }
    }
}
