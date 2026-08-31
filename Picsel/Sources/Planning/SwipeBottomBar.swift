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
        HStack {
            Text("\(selectedCount)곳 선택됨")
                .font(.headline)
                .foregroundColor(.black)
            
            Spacer()
            
            Button(action: onConfirm) {
                Text(selectedCount == 0 ? "경유지 없이 건너뛰기" : "이 장소들로 경로 만들기")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color.black)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
    }
}
