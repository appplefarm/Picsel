//
//  PicselMapPreviews.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/1/26.
//

#if DEBUG
import SwiftUI

#Preview("PicselMap · 선택 지역 161개") {
    PicselMapPreview()
}

private struct PicselMapPreview: View {
    var body: some View {
        switch PicselMapPrototypeData.loadResult {
        case .success(let regions):
            NavigationStack {
                PicselMapView(
                    regions: regions,
                    unlockedRegionCodes: PicselMapPrototypeData.unlockedRegionCodes,
                    records: PicselMapPrototypeData.records,
                    pixelResolution: 128
                )
            }

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
