//
//  SwipeBottomBar.swift
//  Picsel
//
//  Created by 김나영 on 8/31/26.
//


import SwiftUI

struct SwipeBottomBar: View {
    let selectedCount: Int
    var onConfirm: () -> Void
    
    var body: some View {
        VStack {
            Button(action: onConfirm) {
                Text(selectedCount == 0 ? "경유지 없이 건너뛰기" : "\(selectedCount)곳의 장소들로 경로 만들기")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
//                    .background(Color(red: 25/255, green: 140/255, blue: 99/255))
                    .cornerRadius(16)
            }
            .buttonStyle(.primaryGradient)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 10)
        .background(Color.white)
    }
}
