//
//  DataSourceView.swift
//  Picsel
//

import SwiftUI

struct DataSourceView: View {
    var body: some View {
        SettingsModalScaffold(
            title: "API 및 데이터 정보",
            closeAccessibilityLabel: "API 및 데이터 정보 닫기"
        ) {
            LazyVStack(alignment: .leading, spacing: 28) {
                header

                ForEach(Array(DataSourceContent.sections.enumerated()), id: \.offset) { _, section in
                    DataSourceSectionView(section: section)
                }
            }
        }
    }
}

private extension DataSourceView {
    var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("시행일: \(DataSourceContent.effectiveDate) | Picsel")
                .font(PicselFont.caption01)
                .foregroundStyle(Color(hex: 0x8D9795))

            Text("Picsel은 정확하고 다양한 여행 정보를 제공하기 위해 공공데이터와 외부 서비스의 API를 활용합니다.")
                .font(PicselFont.body02)
                .foregroundStyle(Color(hex: 0x688276))
                .lineSpacing(4)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xE7F3EE))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.top, 30)
        }
    }
}

private struct DataSourceSectionView: View {
    let section: DataSourceSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(PicselFont.label03)
                .foregroundStyle(Color(hex: 0x2B3431))

            ForEach(section.paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(PicselFont.caption01)
                    .foregroundStyle(Color(hex: 0x475651))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !section.items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(section.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .frame(width: 7, alignment: .trailing)

                            Text(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(PicselFont.caption01)
                        .foregroundStyle(Color(hex: 0x475651))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            ForEach(section.footerParagraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(PicselFont.caption01)
                    .foregroundStyle(Color(hex: 0x475651))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private enum DataSourceContent {
    static let effectiveDate = "2026년 9월 16일"

    static let sections: [DataSourceSection] = [
        DataSourceSection(
            title: "한국관광공사 관광사진 정보",
            paragraphs: [],
            items: [
                "제공 기관: 한국관광공사",
                "활용 목적: 사진을 활용한 여행지 탐색 및 추천",
                "제공 정보: 관광사진, 촬영 장소, 작품 정보, 지역 정보 등",
                "출처: 한국관광공사 관광사진 공모전 및 TourAPI"
            ],
            footerParagraphs: [
                "일부 사진과 정보의 저작권은 한국관광공사 또는 해당 저작자에게 있습니다. Picsel은 제공 기관이 정한 이용 조건과 출처 표기 기준을 따릅니다."
            ]
        ),
        DataSourceSection(
            title: "관광지 및 지역 정보",
            paragraphs: [],
            items: [
                "제공 기관: 한국관광공사 및 공공데이터포털",
                "활용 목적: 여행지 검색, 장소 정보 제공 및 추천",
                "제공 정보: 장소명, 주소, 좌표, 관광 정보, 이미지 등"
            ],
            footerParagraphs: [
                "제공 기관의 데이터 변경 또는 갱신 시점에 따라 실제 정보와 차이가 있을 수 있습니다."
            ]
        ),
        DataSourceSection(
            title: "지도 및 경로 API",
            paragraphs: [],
            items: [
                "NAVER Maps SDK: 홈 화면과 경로 확인 화면의 지도 표시",
                "카카오모빌리티 길찾기 API: 출발지·경유지·목적지를 이용한 자동차 경로 계산"
            ],
            footerParagraphs: [
                "지도 표시와 경로 계산 과정에는 각 서비스 제공자의 이용약관과 개인정보 처리방침이 적용됩니다."
            ]
        ),
        DataSourceSection(
            title: "외부 지도 및 내비게이션",
            paragraphs: [
                "Picsel은 이용자가 선택한 지도 또는 내비게이션 앱으로 길 안내를 연결합니다."
            ],
            items: [
                "네이버지도",
                "카카오맵",
                "티맵"
            ],
            footerParagraphs: [
                "길 안내를 시작하면 목적지의 장소명과 좌표가 선택한 외부 앱으로 전달될 수 있습니다. 이후 정보 처리는 해당 서비스의 이용약관과 개인정보 처리방침을 따릅니다."
            ]
        ),
        DataSourceSection(
            title: "Apple 기술",
            paragraphs: [
                "Picsel은 iOS 기능 제공을 위해 아래 Apple 기술을 사용합니다. 기기 권한은 iPhone 설정에서 언제든지 변경할 수 있습니다."
            ],
            items: [
                "PhotosUI 사진 선택기: 이용자가 선택한 사진 불러오기",
                "CoreLocation 위치 서비스: 현재 위치와 행정구역 확인",
                "SwiftData: 여행 기록, 선택 사진 및 픽셀 정보의 기기 내 저장",
                "CloudKit Public Database: 개인정보가 아닌 관광 사진 좌표 카탈로그 제공"
            ]
        ),
        DataSourceSection(
            title: "데이터 정확성 안내",
            paragraphs: [
                "외부 기관이 제공하는 데이터는 갱신 시점, 현장 상황 또는 제공 기관의 정책에 따라 실제 정보와 다를 수 있습니다.",
                "Picsel은 장소의 운영 시간, 요금, 출입 가능 여부 및 교통 상황을 보장하지 않습니다. 여행 전에 해당 장소의 공식 채널을 통해 최신 정보를 확인해 주세요."
            ]
        ),
        DataSourceSection(
            title: "문의",
            paragraphs: [
                "API, 데이터 출처 또는 저작권과 관련된 문의는 아래 연락처로 보내주세요."
            ],
            items: [
                "이메일: \(AppContact.supportEmail)",
                "운영 주체: Picsel 운영팀"
            ]
        )
    ]
}

private struct DataSourceSection {
    let title: String
    let paragraphs: [String]
    var items: [String] = []
    var footerParagraphs: [String] = []
}

#Preview {
    NavigationStack {
        DataSourceView()
    }
}
