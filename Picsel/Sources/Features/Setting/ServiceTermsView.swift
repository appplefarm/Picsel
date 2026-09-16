//
//  ServiceTermsView.swift
//  Picsel
//

import SwiftUI

struct ServiceTermsView: View {
    var body: some View {
        SettingsModalScaffold(
            title: "서비스 이용약관",
            closeAccessibilityLabel: "서비스 이용약관 닫기"
        ) {
            LazyVStack(alignment: .leading, spacing: 28) {
                header

                ForEach(Array(ServiceTermsContent.articles.enumerated()), id: \.offset) { _, article in
                    TermsArticleView(article: article)
                }
            }
        }
    }
}

private extension ServiceTermsView {
    var header: some View {
        Text("시행일: \(ServiceTermsContent.effectiveDate) | Picsel")
            .font(.system(size: 12))
            .foregroundStyle(Color(hex: 0x8D9795))
    }
}

private struct TermsArticleView: View {
    let article: TermsArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(article.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: 0x2B3431))

            ForEach(article.paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0x475651))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !article.items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(article.items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text(article.isOrdered ? "\(index + 1)." : "•")
                                .frame(width: article.isOrdered ? 16 : 7, alignment: .trailing)

                            Text(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
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

private enum ServiceTermsContent {
    static let effectiveDate = "2026년 9월 16일"

    static let articles: [TermsArticle] = [
        TermsArticle(
            title: "제1조 목적",
            paragraphs: [
                "본 약관은 Picsel 운영팀(이하 ‘운영팀’)이 제공하는 Picsel 서비스의 이용 조건과 운영팀 및 이용자의 권리·의무를 정하는 것을 목적으로 합니다."
            ]
        ),
        TermsArticle(
            title: "제2조 서비스 내용",
            paragraphs: [
                "Picsel은 이용자가 사진의 분위기와 취향을 바탕으로 새로운 여행지를 발견하고, 여행 기록을 픽셀맵으로 남길 수 있도록 다음 기능을 제공합니다."
            ],
            items: [
                "목적지 및 경유지 추천",
                "지역과 거리 등의 조건을 반영한 장소 탐색",
                "여행 계획 생성 및 기기 내 저장",
                "방문 장소 확인 및 여행 기록 작성",
                "픽셀맵과 여행 히스토리 제공",
                "외부 지도 및 내비게이션 앱 연결"
            ],
            isOrdered: true
        ),
        TermsArticle(
            title: "제3조 약관의 적용 및 변경",
            paragraphs: [
                "이용자가 서비스를 이용하는 동안 본 약관이 적용됩니다.",
                "운영팀은 관련 법령을 위반하지 않는 범위에서 약관을 변경할 수 있으며, 변경 내용과 시행일은 적용 전에 앱의 설정 화면 또는 공개된 약관 페이지를 통해 안내합니다."
            ]
        ),
        TermsArticle(
            title: "제4조 여행지 추천 정보",
            paragraphs: [
                "Picsel이 제공하는 여행지, 경유지, 이동 거리 및 예상 시간 등의 정보는 공공데이터와 외부 서비스에서 제공받은 자료를 기반으로 합니다.",
                "추천 결과는 참고 정보이며 특정 장소의 안전성, 운영 여부 또는 이용 가능성을 보장하지 않습니다. 이용자는 여행 전에 다음 정보를 직접 확인해야 합니다."
            ],
            items: [
                "장소의 실제 운영 여부와 운영 시간",
                "입장료와 예약 필요 여부",
                "교통 및 도로 상황",
                "기상 상황",
                "출입 제한 및 안전 관련 공지"
            ]
        ),
        TermsArticle(
            title: "제5조 위치 및 방문 기록",
            paragraphs: [
                "위치 기반 기능은 이용자의 기기 설정, GPS 신호 및 통신 환경에 따라 실제 위치와 차이가 발생할 수 있습니다.",
                "Picsel의 방문 확인 결과는 여행 기록을 돕기 위한 기능이며 실제 방문 사실을 공식적으로 증명하는 자료로 사용할 수 없습니다.",
                "위치정보는 이용자가 권한을 허용한 경우에만 개인정보 처리방침에서 안내한 목적으로 사용합니다."
            ]
        ),
        TermsArticle(
            title: "제6조 외부 서비스 이용",
            paragraphs: [
                "Picsel은 지도 표시와 경로 계산을 위해 Google Maps Platform과 NAVER Cloud Directions API를 사용하며, 길 안내를 위해 카카오맵·네이버지도·티맵으로 연결할 수 있습니다.",
                "외부 서비스의 화면, 기능, 오류, 정보 정확성 및 이용 과정에는 각 서비스 제공자의 이용약관과 정책이 적용됩니다."
            ]
        ),
        TermsArticle(
            title: "제7조 이용자의 의무",
            paragraphs: [
                "이용자는 다음 행위를 해서는 안 됩니다."
            ],
            items: [
                "허위 여행 기록을 반복적으로 생성하는 행위",
                "서비스의 정상적인 운영을 방해하는 행위",
                "앱 또는 연동 API에 비정상적으로 접근하는 행위",
                "서비스의 데이터나 콘텐츠를 무단으로 복제·배포하는 행위",
                "타인의 저작권·초상권·개인정보 등 권리 또는 관련 법령을 침해하는 행위",
                "Picsel 또는 제3자를 사칭하는 행위"
            ],
            isOrdered: true
        ),
        TermsArticle(
            title: "제8조 이용자 콘텐츠",
            paragraphs: [
                "이용자가 선택한 사진과 작성한 기록의 권리는 이용자에게 있습니다.",
                "이용자는 자신이 사용하는 콘텐츠에 필요한 권리를 보유해야 하며 타인의 저작권, 초상권 또는 개인정보를 침해해서는 안 됩니다.",
                "현재 버전에서 개인 사진과 여행 기록은 서비스 제공을 위해 기기에 저장되고 화면에 표시되며, 별도 동의 없이 광고나 홍보 목적으로 사용하지 않습니다."
            ]
        ),
        TermsArticle(
            title: "제9조 서비스의 변경 및 중단",
            paragraphs: [
                "운영팀은 서비스 개선, 시스템 점검, 장애, 외부 데이터 제공 중단 또는 불가피한 운영상의 사유로 서비스의 일부를 변경하거나 일시적으로 중단할 수 있습니다.",
                "예정된 점검이나 중요한 변경은 가능한 한 사전에 안내하며, 긴급한 장애나 보안 문제가 발생한 경우에는 조치 후 안내할 수 있습니다."
            ]
        ),
        TermsArticle(
            title: "제10조 이용 제한",
            paragraphs: [
                "운영팀은 이용자가 관련 법령 또는 본 약관을 위반하거나 서비스 보안 및 정상적인 운영에 피해를 줄 우려가 있는 경우 해당 기능의 이용을 제한할 수 있습니다.",
                "가능한 경우 제한 사유를 사전에 안내하며, 긴급한 피해가 우려되는 경우에는 먼저 제한한 뒤 그 사유를 안내할 수 있습니다."
            ]
        ),
        TermsArticle(
            title: "제11조 책임의 제한",
            paragraphs: [
                "운영팀은 고의 또는 중대한 과실이 없고 관련 법령에서 허용하는 범위에서 다음 사유로 발생한 손해에 대해 책임을 지지 않습니다."
            ],
            items: [
                "천재지변, 통신 장애 등 운영팀이 통제하기 어려운 사유",
                "이용자의 기기 또는 네트워크 문제",
                "이용자가 잘못된 정보를 입력하거나 권한을 제한하여 발생한 문제",
                "외부 지도, 내비게이션 또는 공공데이터의 오류나 변경",
                "이용자가 추천 정보의 최신성·안전성을 별도로 확인하지 않아 발생한 문제"
            ]
        ),
        TermsArticle(
            title: "제12조 문의 및 분쟁 해결",
            paragraphs: [
                "서비스 이용과 관련된 문의는 설정 > 문의하기 또는 \(AppContact.supportEmail)로 접수할 수 있습니다.",
                "운영팀과 이용자 사이에 분쟁이 발생한 경우 상호 협의를 통해 해결하며, 해결되지 않는 경우 관련 법령에 따른 절차와 관할 법원을 따릅니다."
            ]
        )
    ]
}

private struct TermsArticle {
    let title: String
    let paragraphs: [String]
    var items: [String] = []
    var isOrdered = false
}

#Preview {
    NavigationStack {
        ServiceTermsView()
    }
}
