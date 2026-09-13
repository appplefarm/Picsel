//
//  PrivacyPolicyView.swift
//  Picsel
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Picsel은 여행 경험을 만들기 위해 필요한 정보만 사용하고, 개인 여행 데이터와 공용 콘텐츠를 분리해 관리합니다.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)

                PolicySection(
                    title: "여행 및 픽셀 데이터",
                    items: [
                        "사용자의 여행 기록, 방문 기록 및 픽셀 정보는 iCloud의 CloudKit Private Database에 저장될 수 있습니다.",
                        "해당 정보는 사용자의 개인 데이터로 관리되며 Public Database에 저장하지 않습니다."
                    ]
                )

                PolicySection(
                    title: "위치 정보",
                    items: [
                        "Picsel은 현재 위치 기반 여행 기능 제공을 위해 기기의 위치 정보에 접근합니다.",
                        "현재 위치 좌표는 Picsel의 CloudKit 또는 별도 서버에 저장하지 않습니다.",
                        "현재 위치 정보를 별도의 외부 서버로 전송하지 않습니다."
                    ]
                )

                PolicySection(
                    title: "사진",
                    items: [
                        "사용자가 선택한 개인 사진은 앱 기능 제공을 위해 기기 내에서 사용됩니다.",
                        "사용자의 개인 사진은 CloudKit 또는 Picsel의 별도 서버에 저장하지 않습니다.",
                        "외부 서비스로 전송하지 않습니다."
                    ]
                )

                PolicySection(
                    title: "공용 콘텐츠",
                    items: [
                        "모든 사용자가 볼 수 있는 공용 사진 또는 콘텐츠는 CloudKit Public Database를 통해 제공될 수 있습니다.",
                        "개인 여행 데이터와 공용 콘텐츠 저장 영역은 분리합니다."
                    ]
                )

                PolicySection(
                    title: "문의",
                    items: [
                        "개인정보 관련 문의는 \(AppContact.supportEmail)로 연락해주세요.",
                        "실제 문의 이메일 확정 전까지는 placeholder 주소로 관리합니다."
                    ]
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .background(Color.white)
        .navigationTitle("개인정보 처리방침")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PolicySection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.primary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        Text(item)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
