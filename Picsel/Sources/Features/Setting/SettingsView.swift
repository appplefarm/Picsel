//
//  SettingsView.swift
//  Picsel
//
//  Created by DS on 9/10/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var destination: SettingsDestination?
    @State private var isShowingMailError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    serviceSection
                        .padding(.top, 52)

                    informationSection
                        .padding(.top, 52)

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .background(Color.white)
            .navigationDestination(item: $destination) { destination in
                switch destination {
                case .privacyPolicy:
                    PrivacyPolicyView()
                case .dataSource:
                    DataSourceView()
                }
            }
            .alert("메일 앱을 열 수 없어요", isPresented: $isShowingMailError) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("\(AppContact.supportEmail)로 직접 문의해주세요.")
            }
        }
    }
}

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
                        .background(Circle().fill(Color(.systemGray6)))
                }
                .accessibilityLabel("설정 닫기")
            }

            Text("Picsel을 나에게 맞게 관리해요")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
        }
    }

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

    var informationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("정보")

            SettingsCard {
                SettingsRow(
                    icon: "checkmark.shield",
                    title: "개인정보 처리방침",
                    description: "개인정보 수집·이용 내역"
                ) {
                    destination = .privacyPolicy
                }

                Divider()
                    .padding(.leading, 16)

                SettingsRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "데이터 및 콘텐츠 출처",
                    description: "연동 서비스와 콘텐츠 제공처"
                ) {
                    destination = .dataSource
                }

                Divider()
                    .padding(.leading, 16)

                SettingsRow(
                    icon: "envelope",
                    title: "문의하기",
                    description: "서비스 문의 및 문제 신고"
                ) {
                    openSupportMail()
                }

                Divider()
                    .padding(.leading, 16)

                VersionRow()
            }
        }
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.green)
    }

    func openSupportMail() {
        guard let url = AppContact.supportMailURL else {
            isShowingMailError = true
            return
        }

        openURL(url) { accepted in
            if !accepted {
                isShowingMailError = true
            }
        }
    }
}

private enum SettingsDestination: Hashable, Identifiable {
    case privacyPolicy
    case dataSource

    var id: Self { self }
}

#Preview {
    SettingsView()
}
