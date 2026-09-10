//
//  TripMemoCard.swift
//  Picsel
//
//  픽셀 상세 상단의 기록 카드 — 제목 / 날짜 / 메모 본문
//

import SwiftUI

struct TripMemoCard: View {

    let title: String
    let travelDate: Date
    let memo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer(minLength: 12)

                Text(travelDate, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !memo.isEmpty {
                Text(memo)
                    .font(.body)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.08))
        )
    }
}

#Preview {
    TripMemoCard(
        title: "영덕 바다 따라가는 하루",
        travelDate: .now,
        memo: "이건 여행에 대한 간단한 메모입니다. 150자 이상 쓸 수 없어요."
    )
    .padding()
}
