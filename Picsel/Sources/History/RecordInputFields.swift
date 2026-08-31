//
//  TitleTextField.swift
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
        // TODO: Step 1 - 라벨("제목") + TextField + 둥근 테두리
        EmptyView()
    }
}

/// 내용 입력. 글자수 카운트(0/150)를 같이 보여준다.
struct MemoTextEditor: View {
    @Binding var text: String
    let maxCount: Int

    var body: some View {
        // TODO: Step 1 - 라벨("내용") + TextEditor + 오른쪽 아래 글자수
        // TODO: Step 1 - maxCount 초과 입력 막기 (.onChange)
        EmptyView()
    }
}
