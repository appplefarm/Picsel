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
                    .font(PicselFont.label01)
            }
            .buttonStyle(.primaryGradient)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(Color.white)
    }
}
