//
//  SettingsView.swift
//  Picsel
//
//  Created by DS on 9/10/26.
//
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                header

                serviceSection
                    .padding(.top, 52)

                informationSection
                    .padding(.top, 52)

                accountSection
                    .padding(.top, 52)

                Spacer(minLength: 50)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .background(Color.white)
    }
}


// MARK: - Header

private extension SettingsView {

    var header: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(alignment: .top) {
                Text("설정")
                    .font(.system(size: 32, weight: .bold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                        )
                }
            }

            Text("Picsel을 나에게 맞게 관리해요")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
        }
    }
}

private extension SettingsView {

    var serviceSection: some View {
        VStack(alignment: .leading, spacing: 20) {

            sectionTitle("서비스 설정")

            SettingsCard {
                SettingsRow(
                    icon: "location.fill",
                    title: "네비게이션",
                    description: "기본 길 안내 앱 선택"
                ) {
                    print("네비게이션 설정")
                }
            }
        }
    }
}

private extension SettingsView {

    var informationSection: some View {
        VStack(alignment: .leading, spacing: 20) {

            sectionTitle("정보 및 약관")

            SettingsCard {

                SettingsRow(
                    icon: "checkmark.shield",
                    title: "개인정보 처리방침",
                    description: "개인정보 수집·이용 내역"
                ) {
                    print("개인정보 처리방침")
                }

                Divider()
                    .padding(.leading, 16)

                SettingsRow(
                    icon: "doc",
                    title: "서비스 이용약관",
                    description: "서비스 이용약관과 운영 정책"
                ) {
                    print("서비스 이용약관")
                }

                Divider()
                    .padding(.leading, 16)

                SettingsRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "API 및 데이터 정보",
                    description: "연동 서비스와 데이터 출처"
                ) {
                    print("API 정보")
                }

                Divider()
                    .padding(.leading, 16)

                VersionRow()
            }
        }
    }
}
private extension SettingsView {

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.green)
    }
}
private extension SettingsView {

    var accountSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            sectionTitle("계정 관리")
            
            HStack(spacing: 12) {
                // 로그아웃 버튼
                Button {
                    print("로그아웃 클릭")
                } label: {
                    Text("로그아웃")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // 회원탈퇴 버튼
                Button {
                    print("회원탈퇴 클릭")
                } label: {
                    Text("회원탈퇴")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.red.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
