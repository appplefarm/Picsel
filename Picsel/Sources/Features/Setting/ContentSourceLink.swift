//
//  ContentSourceLink.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/11/26.
//

import SwiftUI

/// 콘텐츠 가까이에 제공처를 표시하고, 같은 출처 안내 화면으로 연결합니다.
struct ContentSourceLink: View {
    let title: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label(title, systemImage: "info.circle")
                .font(.caption)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityHint("데이터 출처와 이용 안내를 엽니다")
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                DataSourceView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("닫기") { isPresented = false }
                        }
                    }
            }
        }
    }
}
