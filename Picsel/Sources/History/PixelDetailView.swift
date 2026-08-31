//
//  PixelDetailView.swift
//  Picsel
//
//  픽셀 상세 — "영덕 픽셀"
//  픽셀맵에서 지역 하나를 눌렀을 때 보여줄 기록 상세 화면.
//

import SwiftUI

/// 타임라인 한 줄에 필요한 값.
/// SwiftData 없이도 Preview가 돌게 하려고 화면 전용 타입으로 둔다.
/// 나중에 RouteStop -> RouteStopDisplay로 변환해서 넘긴다.
struct RouteStopDisplay: Identifiable {
    let id = UUID()
    let name: String
    let travelMinutesToNext: Int?   // 다음 장소까지 이동 시간, 마지막 장소는 nil
}

extension RouteStopDisplay {
    /// TODO: 경로 데이터 연결 전까지 쓰는 목업
    static let mockStops: [RouteStopDisplay] = [
        RouteStopDisplay(name: "호미곶 해맞이광장", travelMinutesToNext: 12),
        RouteStopDisplay(name: "구룡포 일본인가옥거리", travelMinutesToNext: 8),
        RouteStopDisplay(name: "월포해수욕장", travelMinutesToNext: nil)
    ]
}

struct PixelDetailView: View {

    let snapshot: TripRecordSnapshot
    /// TODO: 경로 데이터가 생기면 실제 값으로 교체
    var stops: [RouteStopDisplay] = RouteStopDisplay.mockStops

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("\(snapshot.regionName) 픽셀")
                    .font(.title).bold()
                
                // TODO: 최종 목적지 (수상작 사진) 보여주기
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 300, height: 200)

                TripMemoCard(
                    title: snapshot.title,
                    travelDate: snapshot.travelDate,
                    memo: snapshot.memo
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("그날의 사진")
                        .font(.headline)

                    TripPhotoScroller(photoDataList: snapshot.photoDataList)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("다녀온 경로")
                        .font(.headline)

                    RouteTimelineView(stops: stops)
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PixelDetailView(snapshot: .sample)
    }
}
