//
//  Untitled.swift
//  Picsel
//
//  Created by DS on 9/11/26.
//

import SwiftUI

struct WithdrawalSheetView: View {
    @Binding var isPresented: Bool
    let onWithdraw: () -> Void
    @State private var showConfirmAlert = false

    var body: some View {
        VStack(spacing: 24) {
            // 상단 바 핸들바
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            // 타이틀 및 설명
            VStack(spacing: 12) {
                Text("Picsel을 탈퇴하시겠어요?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Text("탈퇴하면 저장된 여행 기록과 픽셀맵이 삭제되며,\n삭제된 정보는 복구할 수 없어요.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 삭제되는 항목 리스트
            VStack(alignment: .leading, spacing: 12) {
                WithdrawalItemRow(text: "여행 및 방문 장소 기록")
                WithdrawalItemRow(text: "저장한 사진과 여행 메모")
                WithdrawalItemRow(text: "완성한 픽셀맵")
                WithdrawalItemRow(text: "계정 정보")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(16)

            // 하단 버튼 영역
            VStack(spacing: 16) {
                Button(action: {
                    isPresented = false
                }) {
                    Text("계속 이용하기")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.green)
                        .cornerRadius(16)
                }

                Button(action: {
                    showConfirmAlert = true
                }) {
                    Text("회원탈퇴")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .presentationDetents([.height(540)])
        .presentationCornerRadius(30)
        // 최종 확인 얼럿
        .alert("정말 탈퇴하시겠어요?", isPresented: $showConfirmAlert) {
            Button("취소", role: .cancel) { }
            Button("탈퇴하기", role: .destructive) {
                onWithdraw()
            }
        } message: {
            Text("삭제된 여행 기록은 다시 복구할 수 없어요.")
        }
    }
}

// 리스트 내 항목 뷰
struct WithdrawalItemRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}
