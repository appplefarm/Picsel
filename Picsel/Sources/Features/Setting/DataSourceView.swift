//
//  DataSourceView.swift
//  Picsel
//

import SwiftUI

struct DataSourceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Picsel에서 사용하는 지도, 길찾기, 관광 콘텐츠 제공처를 안내합니다. 세부 라이선스는 확인되는 항목부터 순차적으로 반영합니다.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)

                SourceSection(
                    title: "지도 및 길찾기",
                    items: [
                        SourceItem(name: "Google Maps Platform", purpose: "홈 화면 지도 및 위치 기반 UI 제공"),
                        SourceItem(name: "NAVER 지도", purpose: "길찾기 및 경로 안내 기능 제공")
                    ]
                )

                SourceSection(
                    title: "관광 정보",
                    items: [
                        SourceItem(name: "한국관광공사 관광 데이터", purpose: "국내 관광지 및 여행지 정보 제공"),
                        SourceItem(name: "공공데이터포털", purpose: "국내 관광/풍경 관련 공공데이터 활용")
                    ]
                )

                SourceSection(
                    title: "사진 및 콘텐츠",
                    items: [
                        SourceItem(name: "관광공모전 선정작", purpose: "사진 기반 여행지 탐색 콘텐츠 제공"),
                        SourceItem(name: "공공데이터 기반 국내 관광/풍경 이미지", purpose: "관광 콘텐츠 보강")
                    ]
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("라이선스 안내")
                        .font(.system(size: 18, weight: .bold))

                    Text("세부 출처 및 라이선스 정보 확인 후 반영 예정")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6).opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .background(Color.white)
        .navigationTitle("데이터 및 콘텐츠 출처")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SourceSection: View {
    let title: String
    let items: [SourceItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.primary)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    SourceItemRow(item: item)

                    if item.id != items.last?.id {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.green.opacity(0.18), lineWidth: 1)
            }
        }
    }
}

private struct SourceItemRow: View {
    let item: SourceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary)

            Text(item.purpose)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct SourceItem: Identifiable {
    let id = UUID()
    let name: String
    let purpose: String
}

#Preview {
    NavigationStack {
        DataSourceView()
    }
}
