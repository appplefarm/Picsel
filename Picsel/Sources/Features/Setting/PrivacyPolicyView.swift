//
//  PrivacyPolicyView.swift
//  Picsel
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        SettingsModalScaffold(
            title: "개인정보 처리방침",
            closeAccessibilityLabel: "개인정보 처리방침 닫기"
        ) {
            LazyVStack(alignment: .leading, spacing: 0) {
                header

                ForEach(Array(PrivacyPolicyContent.sections.enumerated()), id: \.offset) { _, section in
                    PolicySection(section: section)
                        .padding(.top, 28)
                }
            }
        }
    }
}

private extension PrivacyPolicyView {
    var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("시행일: \(PrivacyPolicyContent.effectiveDate) | Picsel")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: 0x8D9795))

            Text("Picsel 운영팀(이하 ‘운영팀’)은 이용자의 개인정보를 중요하게 생각합니다. 이 방침은 현재 버전의 Picsel이 실제로 처리하는 정보와 이용 목적, 저장 방식을 안내합니다.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: 0x688276))
                .lineSpacing(4)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xE7F3EE))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.top, 24)
        }
    }
}

private struct PolicySection: View {
    let section: PolicySectionContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: 0x2B3431))

            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                PolicyBlockView(block: block)
            }

            ForEach(section.links) { link in
                Link(destination: link.url) {
                    HStack(spacing: 5) {
                        Text(link.title)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PicselColor.navigationButtonHighlight)
                }
                .accessibilityHint("외부 웹 페이지를 엽니다")
            }
        }
    }
}

private struct PolicyBlockView: View {
    let block: PolicyBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let heading = block.heading {
                Text(heading)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x36423D))
            }

            if let paragraph = block.paragraph {
                Text(paragraph)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0x475651))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !block.items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(block.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color(hex: 0x688276))
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)

                            Text(item)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: 0x475651))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private enum PrivacyPolicyContent {
    static let effectiveDate = "2026년 9월 16일"
    static let lastUpdatedDate = "2026년 9월 14일"

    static let sections: [PolicySectionContent] = [
        PolicySectionContent(
            title: "1. 처리하는 정보",
            blocks: [
                PolicyBlock(
                    paragraph: "Picsel은 회원가입이나 로그인 없이 이용할 수 있으며, 이메일·닉네임·소셜 로그인 식별자·프로필 이미지 등의 회원정보를 수집하지 않습니다."
                ),
                PolicyBlock(
                    heading: "여행지 추천 및 여행 기록",
                    items: [
                        "이용자가 선택한 목적지와 경유지의 이름·주소·좌표",
                        "여행 일정, 방문 여부, 여행 제목과 메모",
                        "선택한 지역·거리 등의 추천 조건",
                        "저장한 장소, 여행 히스토리 및 픽셀맵 기록"
                    ]
                ),
                PolicyBlock(
                    heading: "위치정보",
                    paragraph: "이용자가 위치 권한을 허용한 경우 현재 위치와 해당 위치의 행정구역명이 여행 반경, 지도 중심, 주변 여행지 추천 및 경로 계산에 사용됩니다."
                ),
                PolicyBlock(
                    heading: "사진",
                    paragraph: "이용자가 iOS 사진 선택기에서 직접 선택한 사진 데이터만 여행 기록에 사용할 수 있습니다. 선택하지 않은 사진을 임의로 열람하지 않으며, 촬영 일시나 사진 속 위치정보를 별도로 추출해 이용하지 않습니다."
                )
            ]
        ),
        PolicySectionContent(
            title: "2. 정보 이용 목적",
            blocks: [
                PolicyBlock(items: [
                    "현재 위치를 기준으로 지도 중심과 여행 반경 표시",
                    "선택 조건에 맞는 여행지와 경유지 추천",
                    "출발지·경유지·목적지를 이용한 이동 경로 계산",
                    "여행 계획, 방문 기록, 여행 히스토리 및 픽셀맵 생성",
                    "사용자가 선택한 개인 사진을 여행 기록에 첨부"
                ])
            ]
        ),
        PolicySectionContent(
            title: "3. 저장 위치 및 보유 기간",
            blocks: [
                PolicyBlock(items: [
                    "여행 기록, 방문 장소, 픽셀 정보와 선택 사진은 현재 버전에서 SwiftData를 통해 기기 내부에 저장됩니다.",
                    "현재 위치 좌표는 지도 표시와 경로 계산에 필요한 동안 사용되며, Picsel의 영구 저장소에 별도로 저장하지 않습니다.",
                    "목적지와 경유지 좌표는 여행 기록의 일부로 기기에 저장될 수 있습니다.",
                    "저장된 앱 데이터는 관련 기록을 삭제하거나 앱을 삭제할 때까지 기기에 남을 수 있습니다."
                ]),
                PolicyBlock(
                    paragraph: "현재 버전은 CloudKit Private/Public Database를 통한 개인 데이터 또는 공용 콘텐츠 동기화를 사용하지 않습니다. 향후 CloudKit 저장 기능을 제공하는 경우 적용 전에 이 방침을 갱신합니다."
                )
            ]
        ),
        PolicySectionContent(
            title: "4. 외부 서비스 이용 및 정보 전달",
            blocks: [
                PolicyBlock(
                    paragraph: "Picsel은 개인정보를 판매하지 않습니다. 다만 기능 제공 과정에서 아래 외부 서비스로 필요한 정보가 전달될 수 있으며, 이후 처리는 각 서비스의 정책을 따릅니다."
                ),
                PolicyBlock(items: [
                    "Apple Core Location 및 지오코딩: 현재 위치 확인과 행정구역명 변환에 iOS 시스템 서비스를 사용합니다.",
                    "Google Maps Platform: 지도 화면과 지도 데이터를 제공하며, 서비스 요청 과정에서 Google이 접속 정보 등을 처리할 수 있습니다.",
                    "카카오모빌리티 길찾기 API: 경로 확인 시 현재 출발지, 경유지 및 목적지 좌표가 경로 계산을 위해 전송됩니다.",
                    "카카오맵·네이버지도·티맵: 이용자가 길 안내를 직접 실행하면 목적지 이름과 좌표가 선택한 앱에 전달됩니다. 출발지는 해당 외부 앱이 현재 위치를 기준으로 결정합니다.",
                    "한국관광공사 관광정보 API: 여행지 추천을 위해 선택 지역과 시·군·구 조건이 요청에 포함될 수 있습니다."
                ])
            ],
            links: [
                PolicyLink(
                    title: "Google 개인정보처리방침 확인",
                    url: URL(string: "https://policies.google.com/privacy")!
                ),
                PolicyLink(
                    title: "카카오모빌리티 개인정보처리방침 확인",
                    url: URL(string: "https://policy.kakaomobility.com/ko/privacy/")!
                )
            ]
        ),
        PolicySectionContent(
            title: "5. 사진 및 공용 콘텐츠",
            blocks: [
                PolicyBlock(items: [
                    "개인 사진은 여행 기록과 함께 기기 내부에서만 사용되며 Picsel 서버나 CloudKit에 업로드하지 않습니다.",
                    "관광공모전 선정작과 공공데이터 기반 관광 사진은 여행지 탐색을 위한 공용 콘텐츠로 제공됩니다.",
                    "현재 버전에는 이용자가 개인 사진을 공용 콘텐츠로 업로드하는 기능이 없습니다.",
                    "콘텐츠별 제공처와 확인된 이용 정보는 ‘데이터 및 콘텐츠 출처’ 화면에서 안내합니다."
                ])
            ]
        ),
        PolicySectionContent(
            title: "6. 이용자의 선택과 권리",
            blocks: [
                PolicyBlock(items: [
                    "위치 권한은 iPhone의 설정 > 개인정보 보호 및 보안 > 위치 서비스에서 언제든지 변경할 수 있습니다.",
                    "사진은 시스템 사진 선택기를 통해 이용자가 선택한 항목만 앱에 전달됩니다.",
                    "위치 권한을 허용하지 않아도 앱은 기본 위치를 사용해 실행되지만, 현재 위치 기반 기능은 제한될 수 있습니다.",
                    "개인정보 처리에 관한 문의는 아래 문의처로 요청할 수 있습니다."
                ])
            ]
        ),
        PolicySectionContent(
            title: "7. 앱 권한 안내",
            blocks: [
                PolicyBlock(items: [
                    "위치(앱을 사용하는 동안): 현재 위치 기반 여행 반경, 주변 여행지 추천 및 경로 계산",
                    "사진 선택: 여행 기록에 추가할 사진을 사용자가 직접 선택"
                ]),
                PolicyBlock(
                    paragraph: "Picsel은 현재 알림 권한을 요청하지 않습니다. 선택 권한을 허용하지 않아도 기본 기능을 이용할 수 있으나 해당 권한이 필요한 기능은 제한될 수 있습니다."
                )
            ]
        ),
        PolicySectionContent(
            title: "8. 정보 보호 방식",
            blocks: [
                PolicyBlock(items: [
                    "개인 여행 데이터와 사진은 iOS 앱 샌드박스의 기기 저장 영역에서 관리합니다.",
                    "현재 위치를 개인 여행 기록과 함께 영구 저장하지 않습니다.",
                    "외부 서비스에는 해당 기능 제공에 필요한 범위의 정보만 전달합니다."
                ])
            ]
        ),
        PolicySectionContent(
            title: "9. 만 14세 미만 이용자",
            blocks: [
                PolicyBlock(
                    paragraph: "Picsel은 만 14세 미만 아동을 대상으로 회원정보를 수집하는 서비스를 제공하지 않습니다. 보호자는 기기의 위치 및 사진 접근 설정을 통해 권한을 관리할 수 있습니다."
                )
            ]
        ),
        PolicySectionContent(
            title: "10. 개인정보 보호 문의처",
            blocks: [
                PolicyBlock(items: [
                    "운영 주체: Picsel 운영팀",
                    "이메일: \(AppContact.supportEmail)"
                ]),
                PolicyBlock(
                    paragraph: "앱의 설정 > 문의하기를 통해 기본 메일 앱을 열 수 있습니다. 문의 내용은 Picsel 앱 내부에 저장되지 않습니다."
                )
            ]
        ),
        PolicySectionContent(
            title: "11. 개인정보 처리방침의 변경",
            blocks: [
                PolicyBlock(
                    paragraph: "서비스의 정보 처리 방식이 변경되면 적용 전에 이 화면과 공개된 개인정보 처리방침을 갱신하고 시행일 및 최종 수정일을 표시합니다."
                )
            ]
        )
    ]
}

private struct PolicySectionContent {
    let title: String
    let blocks: [PolicyBlock]
    var links: [PolicyLink] = []
}

private struct PolicyBlock {
    var heading: String?
    var paragraph: String?
    var items: [String] = []
}

private struct PolicyLink: Identifiable {
    let title: String
    let url: URL

    var id: String { url.absoluteString }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
