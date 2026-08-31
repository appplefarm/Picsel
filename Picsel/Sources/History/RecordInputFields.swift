//
//  RecordInputFields.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import SwiftUI

/// 제목 입력. 지금 단계에서는 단순 TextField.
/// (지역명 + 여행 자동 생성은 나중 이슈)
struct TitleTextField: View {
    @Binding var text: String
    var placeholder: String = "지역명 + 여행"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("제목")
                .font(.headline)
                .bold()
            
            TextField(placeholder, text: $text)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

/// 내용 입력. 글자수 카운트(0/150)를 같이 보여준다.
struct MemoTextEditor: View {
    @Binding var text: String
    let maxCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내용")
                .font(.headline)
                .bold()
            
            ZStack(alignment: .topLeading) {
                // Background Border Area
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                
                // Placeholder
                if text.isEmpty {
                    Text("사진들과 관련해 짧은 글을 남겨보세요")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                
                // Text Input
                TextEditor(text: $text)
                    .font(.body)
                    .padding(8)
                    .scrollContentBackground(.hidden) // 배경 투명 처리
                    .onChange(of: text) { newValue in
                        if newValue.count > maxCount {
                            text = String(newValue.prefix(maxCount))
                        }
                    }
                
                // Character Counter (오른쪽 아래)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(text.count)/\(maxCount)")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.trailing, 16)
                            .padding(.bottom, 12)
                    }
                }
            }
            .frame(height: 140)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var title = ""
        @State private var memo = ""
        
        var body: some View {
            VStack(spacing: 24) {
                TitleTextField(text: $title)
                MemoTextEditor(text: $memo, maxCount: 150)
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}
