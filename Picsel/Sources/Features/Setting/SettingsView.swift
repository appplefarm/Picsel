//
//  SettingsView.swift
//  Picsel
//
//  Created by DS on 9/10/26.
//
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let onLogout: () -> Void
    let onWithdraw: () -> Void

    @State private var isShowingLogoutAlert = false
    @State private var showWithdrawalSheet = false
    @State private var destination: SettingsDestination?
    @State private var isShowingMailError = false

    var body: some View {
        NavigationStack {
            ZStack {
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

                if isShowingLogoutAlert {
                    logoutOverlay
                        .transition(.opacity)
                }
            }
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
        .animation(.easeInOut(duration: 0.2), value: isShowingLogoutAlert)
        .sheet(isPresented: $showWithdrawalSheet) {
            WithdrawalSheetView(
                isPresented: $showWithdrawalSheet,
                onWithdraw: handleWithdrawalPlaceholder
            )
            .presentationDetents([.height(520)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
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
                    isShowingLogoutAlert = true
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
                    showWithdrawalSheet = true
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

private extension SettingsView {

    var logoutOverlay: some View {
        ZStack {

            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowingLogoutAlert = false
                }

            VStack(spacing: 0) {

                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
                    .frame(width: 64, height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.green.opacity(0.1))
                    )

                Text("로그아웃할까요?")
                    .font(.system(size: 26, weight: .bold))
                    .padding(.top, 20)

                Text("언제든지 다시 로그인할 수 있어요.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)

                HStack(spacing: 14) {

                    Button {
                        isShowingLogoutAlert = false
                    } label: {
                        Text("취소")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(.systemGray6))
                            )
                    }

                    Button {
                        logout()
                    } label: {
                        Text("로그아웃")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.red.opacity(0.08))
                            )
                    }
                }
                .padding(.top, 26)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 36)
            .frame(maxWidth: 500)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 40)
        }
    }
}
private extension SettingsView {

    func logout() {
        isShowingLogoutAlert = false
        onLogout()
    }

    func handleWithdrawalPlaceholder() {
        // TODO: 회원탈퇴 정책과 데이터 삭제 범위가 확정되면 실제 탈퇴 로직을 연결합니다.
        showWithdrawalSheet = false
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
    SettingsView(
        onLogout: { print("로그아웃") },
        onWithdraw: { print("회원탈퇴") }
    )
    .modelContainer(for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self], inMemory: true)
}
