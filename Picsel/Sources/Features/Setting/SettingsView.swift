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
                VStack(alignment: .leading, spacing: 35) {
                    serviceSection
                    informationSection
                }
                .padding(.horizontal, 35)
                .padding(.top, 48)
                .padding(.bottom, 40)
            }
            .background(PicselColor.settingsBackground.ignoresSafeArea())
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PicselColor.settingsBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(PicselColor.homeText)
                    .accessibilityLabel("설정 닫기")
                }
            }
            .navigationDestination(item: $destination) { route in
                switch route {
                case .navigationApp:
                    NavigationAppSelectionView(presentation: .settings) {
                        destination = nil
                    }
                case .privacyPolicy:
                    PrivacyPolicyView()
                case .serviceTerms:
                    ServiceTermsView()
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
    var serviceSection: some View {
        VStack(alignment: .leading, spacing: 17) {
            sectionTitle("서비스 설정")

            SettingsCard {
                SettingsRow(
                    icon: "location.fill",
                    title: "네비게이션",
                    description: "기본 길 안내 앱 선택"
                ) {
                    destination = .navigationApp
                }
            }
        }
    }

    var informationSection: some View {
        VStack(alignment: .leading, spacing: 26) {
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
                    .padding(.horizontal, 10)

                SettingsRow(
                    icon: "doc.text",
                    title: "서비스 이용약관",
                    description: "서비스 이용 조건과 운영 정책"
                ) {
                    destination = .serviceTerms
                }

                Divider()
                    .padding(.horizontal, 10)

                SettingsRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "데이터 및 콘텐츠 출처",
                    description: "연동 서비스와 콘텐츠 제공처"
                ) {
                    destination = .dataSource
                }

                Divider()
                    .padding(.horizontal, 10)

                SettingsRow(
                    icon: "envelope",
                    title: "문의하기",
                    description: "서비스 문의 및 문제 신고"
                ) {
                    openSupportMail()
                }

                Divider()
                    .padding(.horizontal, 10)

                VersionRow()
            }
        }
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(PicselColor.settingsSectionTitle)
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
    case navigationApp
    case privacyPolicy
    case serviceTerms
    case dataSource

    var id: Self { self }
}

#Preview {
    SettingsView()
}
