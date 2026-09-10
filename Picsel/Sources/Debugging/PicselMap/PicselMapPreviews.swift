//
//  PicselMapPreviews.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/1/26.
//

#if DEBUG
import SwiftUI

/// 실제 픽셀맵에 샘플 기록과 탭 배치를 제공하는 프리뷰 전용 컨테이너입니다.
struct PicselMapPreview: View {
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            // 홈의 지도 SDK 초기화와 위치 권한 요청은 프리뷰에서 실행하지 않습니다.
            ContentUnavailableView("홈 탭", systemImage: "house.fill")
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .tag(0)

            NavigationStack {
                map
            }
            .tabItem {
                Label("픽셀맵", systemImage: "mappin.and.ellipse")
            }
            .tag(1)
        }
        .tint(.primary)
    }

    @ViewBuilder
    private var map: some View {
        switch PicselMapPrototypeData.loadResult {
        case .success(let regions):
            PicselMapView(
                regions: regions,
                unlockedRegionCodes: PicselMapPrototypeData.unlockedRegionCodes,
                records: PicselMapPrototypeData.records,
                pixelResolution: 128
            )

        case .failure(let error):
            ContentUnavailableView(
                "프리뷰 데이터를 불러오지 못했어요",
                systemImage: "map",
                description: Text(error.localizedDescription)
            )
        }
    }
}

#Preview("지도 서브뷰 · 단독 재사용") {
    @Previewable @State var selectedCode: String?

    AdministrativeRegionMapView(
        regions: PicselMapPrototypeData.regions,
        unlockedRegionCodes: PicselMapPrototypeData.unlockedRegionCodes,
        selectedRegionCode: selectedCode
    ) { selectedCode = $0 }
        .frame(height: 420)
        .padding(24)
}

#Preview("픽셀맵 · 첫 여행 전") {
    NavigationStack {
        PicselMapView(regions: PicselMapPrototypeData.regions)
    }
}
#endif
