//
//  DataSourceView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/11/26.
//

import GoogleMaps
import SwiftUI

struct DataSourceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Picsel에서 사용하는 콘텐츠와 지도 서비스의 출처입니다. 콘텐츠마다 이용 조건이 다르며, 이 안내가 재사용 허락을 대신하지는 않습니다.")
                    .foregroundStyle(.secondary)

                SourceSection(title: "관광사진 및 관광 정보") {
                    Text("한국관광공사 · TourAPI")
                        .font(.headline)
                    Text("목적지 관광사진과 경유지 관광 정보를 제공합니다. 현재 포항 사진 목록과 장소 정보는 앱에 포함되어 있으며, 이미지는 한국관광공사의 URL에서 불러옵니다.")
                    SourceExternalLink("한국관광콘텐츠랩", url: ContentSources.tourism)
                    SourceExternalLink("관광사진 API 안내", url: ContentSources.photoAPI)
                    SourceExternalLink("이용약관", url: ContentSources.tourismTerms)
                    SourceExternalLink("저작권 보호정책", url: ContentSources.tourismCopyright)
                    Text("사진별 공공누리 유형과 별도 이용 허락을 확인해야 합니다. 출처와 표시된 작가명을 유지해야 하며, 유형에 따라 상업적 이용이나 변경이 제한됩니다. 공공누리 표시가 없는 사진은 제공처와 사전 협의가 필요합니다.")
                        .foregroundStyle(.secondary)
                }

                SourceSection(title: "픽셀맵 행정경계") {
                    Text("국토교통부 · 브이월드 법정구역정보")
                        .font(.headline)
                    Text("2026년 9월 9일 배포본의 시군구 경계를 사용합니다. 원본 속성 기준일은 9월 6일입니다.")
                    Text("Picsel에서 좌표 변환, 도형 경량화·픽셀화, 시 단위 통합과 대구 남구 속성 보정을 적용했습니다. 여행 기록 표현용으로, 법적 경계 판단이나 정밀 측량에 사용할 수 없습니다.")
                    SourceExternalLink("원본 데이터 및 이용 조건", url: ContentSources.boundaries)
                    Text("제공 페이지에는 CC BY(저작자 표시)로 표기되어 있으나, 연결된 CCL 링크는 BY-NC-ND로 서로 다릅니다. 재사용 전 제공처에 적용 조건을 확인해야 합니다. 가공된 픽셀맵이 원본 제공자의 승인이나 보증을 뜻하지 않습니다.")
                        .foregroundStyle(.secondary)
                }

                SourceSection(title: "지도 및 길찾기") {
                    Text("Google Maps Platform")
                        .font(.headline)
                    Text("홈 지도를 제공합니다. 지도에 표시되는 Google 로고와 데이터 저작권 표시는 SDK가 제공합니다.")
                    SourceExternalLink("Google Maps Platform 이용약관", url: ContentSources.googleTerms)
                    SourceExternalLink("지도 출처 표시 정책", url: ContentSources.googleAttribution)
                    NavigationLink("Google Maps SDK 오픈소스 라이선스") {
                        GoogleMapsLicenseView()
                    }
                    .padding(.vertical, 8)

                    Divider()
                    Text("NAVER Maps")
                        .font(.headline)
                    Text("최종 경로 확인의 지도와 자동차 길찾기를 제공합니다. 경로 지도의 NAVER 로고를 누르면 SDK의 법적 공지와 오픈소스 라이선스를 확인할 수 있습니다.")
                    SourceExternalLink("NAVER 지도 SDK 안내", url: ContentSources.naverGuide)
                }

                Text("지도 서비스의 이용약관과 SDK에 포함된 오픈소스 라이선스는 서로 별개입니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .lineSpacing(4)
            .padding(24)
        }
        .background(Color(.systemBackground))
        .foregroundStyle(.primary)
        .navigationTitle("데이터 및 콘텐츠 출처")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SourceSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct SourceExternalLink: View {
    let title: String
    let url: URL

    init(_ title: String, url: URL) {
        self.title = title
        self.url = url
    }

    var body: some View {
        Link(destination: url) {
            Label(title, systemImage: "arrow.up.right.square")
                .font(.footnote)
                .padding(.vertical, 6)
        }
    }
}

/// SDK가 제공하는 원문을 사용하여 버전 업데이트 때 고지가 누락되지 않도록 합니다.
private struct GoogleMapsLicenseView: View {
    @State private var licenseText = ""

    var body: some View {
        ScrollView {
            Text(verbatim: licenseText)
                .font(.footnote)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .navigationTitle("Google Maps 라이선스")
        .navigationBarTitleDisplayMode(.inline)
        .task { licenseText = GMSServices.openSourceLicenseInfo() }
    }
}

#Preview {
    NavigationStack {
        DataSourceView()
    }
}
