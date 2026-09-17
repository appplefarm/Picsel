//
//  SettingsView.swift
//  Picsel
//
//  Created by DS on 9/10/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var isNavigationAppPresented = false
    @State private var presentedSheet: SettingsSheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 35) {
                serviceSection
                informationSection
            }
            .padding(.horizontal, 27)
            .padding(.top, 48)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(PicselColor.settingsBackground.ignoresSafeArea())
        .settingsNavigationBar(title: "설정")
        .preferredColorScheme(.light)
        .navigationDestination(isPresented: $isNavigationAppPresented) {
            NavigationAppSelectionView(presentation: .settings) {
                isNavigationAppPresented = false
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .privacyPolicy:
                    PrivacyPolicyView()
                case .serviceTerms:
                    ServiceTermsView()
                case .dataSource:
                    DataSourceView()
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
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
                    description: "기본 길 안내 앱 선택",
                    minHeight: 70
                ) {
                    isNavigationAppPresented = true
                }
            }
        }
    }

    var informationSection: some View {
        VStack(alignment: .leading, spacing: 26) {
            sectionTitle("정보 및 약관")

            SettingsCard {
                SettingsRow(
                    icon: "checkmark.shield",
                    title: "개인정보 처리방침",
                    description: "개인정보 수집·이용 내역"
                ) {
                    presentedSheet = .privacyPolicy
                }

                Divider()
                    .padding(.leading, 20)
                    .padding(.trailing, 28)

                SettingsRow(
                    icon: "doc.text",
                    title: "서비스 이용약관",
                    description: "서비스 이용약관과 운영 정책"
                ) {
                    presentedSheet = .serviceTerms
                }

                Divider()
                    .padding(.leading, 20)
                    .padding(.trailing, 28)

                SettingsRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "API 및 데이터 정보",
                    description: "연동 서비스와 데이터 출처"
                ) {
                    presentedSheet = .dataSource
                }

                Divider()
                    .padding(.leading, 20)
                    .padding(.trailing, 28)

                SettingsRow(
                    icon: "envelope",
                    title: "문의하기",
                    description: AppContact.supportEmail
                ) {
                    guard let url = AppContact.supportMailURL else { return }
                    openURL(url)
                }

                Divider()
                    .padding(.leading, 20)
                    .padding(.trailing, 28)

                VersionRow()
            }
        }
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(PicselFont.label01)
            .foregroundStyle(PicselColor.settingsSectionTitle)
    }
}

private enum SettingsSheet: Hashable, Identifiable {
    case privacyPolicy
    case serviceTerms
    case dataSource

    var id: Self { self }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
