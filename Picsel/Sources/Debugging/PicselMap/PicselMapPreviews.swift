//
//  PicselMapPreviews.swift
//  Picsel
//
//  Created by JonghyeonLee on 9/1/26.
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
                    pixelResolution: 180
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
#endif
