//
//  PixelUnlockedView.swift
//  Picsel
//
//  18_픽셀_획득 — "새로운 픽셀이 채워졌어요!"
//  저장 직후 결과 화면.
//

import SwiftData
import SwiftUI

struct PixelUnlockedView: View {

    let snapshot: TripRecordSnapshot

    /// 이번 여행으로 채운 칸입니다. 픽셀을 못 받은 여행이면 nil입니다.
    let unlockedRegionCode: String?

    @Environment(AppRouter.self) private var router
    @Query private var pixels: [UserPixel]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새로운 픽셀이 채워졌어요!")
                .font(.title)
                .fontWeight(.bold)

            Text("\(snapshot.regionName) 여행이 나의 픽셀 지도에 기록됐어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            PixelUnlockedMapView(
                highlightedRegionCode: unlockedRegionCode,
                unlockedRegionCodes: previouslyUnlockedRegionCodes
            )
            .frame(maxWidth: .infinity)
            .frame(height: 240)

            TripSummaryCard(
                thumbnailData: snapshot.representativePhotoData,
                travelDate: snapshot.travelDate,
                title: snapshot.title,
                photoCount: snapshot.photoCount,
                placeCount: snapshot.placeCount
            )

            Spacer()

            Button {
                router.finishTripFlow(returningTo: .home)
            } label: {
                Text("홈으로")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .foregroundStyle(.primary)

            Button {
                router.finishTripFlow(returningTo: .picselMap)
            } label: {
                Text("픽셀맵 확인하기")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                    )
            }
        }
        .padding(20)
        .navigationBarBackButtonHidden(true)
    }

    /// 이번에 채운 칸을 뺀 나머지입니다.
    /// 저장이 이미 끝난 뒤라 새 픽셀도 목록에 들어 있어, 강조 대상과 겹치지 않게 걸러 냅니다.
    private var previouslyUnlockedRegionCodes: Set<String> {
        var codes = Set(pixels.map { String($0.regionCode) })
        if let unlockedRegionCode {
            codes.remove(unlockedRegionCode)
        }
        return codes
    }
}

#Preview {
    NavigationStack {
        PixelUnlockedView(snapshot: .sample, unlockedRegionCode: "4711")
    }
    .environment(AppRouter())
    .modelContainer(
        for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self],
        inMemory: true
    )
}
