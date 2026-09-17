//
//  RecordInputFields.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import SwiftUI

/// 제목 입력.
/// 화면 진입 시 "지역명 + 여행"이 기본값으로 채워지지만, 그대로 지우고 고칠 수 있다.
struct TitleTextField: View {
    @Binding var text: String
    @FocusState.Binding var focusedField: TripRecordField?
    var placeholder: String = "지역명 + 여행"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("제목")
                .font(PicselFont.label01)
                .foregroundStyle(PicselColor.textPrimary)

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .foregroundStyle(PicselColor.inputPlaceholder)
            )
            .font(PicselFont.body02)
            .foregroundStyle(PicselColor.textPrimary)
            .focused($focusedField, equals: .title)
            .submitLabel(.next)
            .onSubmit { focusedField = .memo }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(fieldBackground)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(PicselColor.surface)
            .overlay {
                // stroke는 선의 절반이 도형 밖으로 나가 모서리가 흐려집니다.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(PicselColor.inputBorder, lineWidth: 1)
            }
    }
}

/// 내용 입력. 글자수 카운트(0/150)를 같이 보여준다.
struct MemoTextEditor: View {
    @Binding var text: String
    @FocusState.Binding var focusedField: TripRecordField?
    let maxCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내용")
                .font(PicselFont.label01)
                .foregroundStyle(PicselColor.textPrimary)

            ZStack(alignment: .topLeading) {
                editor

                if text.isEmpty {
                    placeholder
                }

                characterCount
            }
            .frame(height: 120)
            .background(fieldBackground)
        }
    }

    private var editor: some View {
        TextEditor(text: $text)
            .font(PicselFont.body02)
            .foregroundStyle(PicselColor.textPrimary)
            .scrollContentBackground(.hidden)
            .focused($focusedField, equals: .memo)
            .onChange(of: text) { _, newValue in
                guard newValue.count > maxCount else { return }
                text = String(newValue.prefix(maxCount))
            }
            // TextEditor의 기본 여백은 가로 5pt, 세로 8pt입니다.
            // 안내 문구와 동일한 시작점(가로 16pt / 세로 14pt)에 맞춥니다.
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            // 글자 수 표시와 본문이 겹치지 않도록 아래를 비워 둡니다.
            .padding(.bottom, 18)
    }

    private var placeholder: some View {
        Text("사진들과 관련해 짧은 글을 남겨보세요")
            .font(PicselFont.body02)
            .foregroundStyle(PicselColor.inputPlaceholder)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            // 글자를 누르면 입력이 시작되도록 탭을 아래 TextEditor로 흘려보냅니다.
            .allowsHitTesting(false)
    }

    private var characterCount: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Text("\(text.count)/\(maxCount)")
                    .font(PicselFont.caption01)
                    .foregroundStyle(PicselColor.textDisabled)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .allowsHitTesting(false)
        .accessibilityLabel("\(maxCount)자 중 \(text.count)자 입력")
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(PicselColor.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(PicselColor.inputBorder, lineWidth: 1)
            }
    }
}

#Preview("입력 칸") {
    struct PreviewWrapper: View {
        @State private var title = ""
        @State private var memo = ""
        @FocusState private var focusedField: TripRecordField?

        var body: some View {
            VStack(spacing: 24) {
                TitleTextField(text: $title, focusedField: $focusedField)
                MemoTextEditor(text: $memo, focusedField: $focusedField, maxCount: 150)
            }
            .padding(20)
            .background(PicselColor.backgroundWarmWhite)
        }
    }

    return PreviewWrapper()
}

#Preview("값이 있을 때") {
    struct PreviewWrapper: View {
        @State private var title = "포항 여행"
        @State private var memo = "바다를 따라 걸으며 남긴 기록이에요."
        @FocusState private var focusedField: TripRecordField?

        var body: some View {
            VStack(spacing: 24) {
                TitleTextField(text: $title, focusedField: $focusedField)
                MemoTextEditor(text: $memo, focusedField: $focusedField, maxCount: 150)
            }
            .padding(20)
            .background(PicselColor.backgroundWarmWhite)
        }
    }

    return PreviewWrapper()
}
