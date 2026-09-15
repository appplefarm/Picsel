//
//  PixelDetailView.swift
//  Picsel
//
//  기록 상세 — 목적지 사진 위로 기록 시트가 덮는 화면.
//  픽셀맵과 픽셀 히스토리 양쪽에서 같은 화면으로 들어옵니다.
//

import SwiftUI

/// 타임라인 한 줄에 필요한 값.
/// SwiftData 없이도 Preview가 돌게 하려고 화면 전용 타입으로 둔다.
struct RouteStopDisplay: Identifiable {
    let id = UUID()
    let name: String
    let travelMinutesToNext: Int?   // 다음 장소까지 이동 시간, 마지막 장소는 nil
}

extension RouteStopDisplay {
    /// TODO: 경로 데이터 연결 전까지 쓰는 목업
    static let mockStops: [RouteStopDisplay] = [
        RouteStopDisplay(name: "영일대해수욕장", travelMinutesToNext: 12),
        RouteStopDisplay(name: "환호공원", travelMinutesToNext: 8),
        RouteStopDisplay(name: "해안로 작은 카페", travelMinutesToNext: nil)
    ]
}

struct PixelDetailView: View {

    let snapshot: TripRecordSnapshot
    /// TODO: 경로 데이터가 생기면 실제 값으로 교체
    var stops: [RouteStopDisplay] = RouteStopDisplay.mockStops

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 사진은 상태 표시줄까지 올라가야 하지만 버튼은 안전 영역 안에 있어야 합니다.
        // ScrollView에만 ignoresSafeArea를 걸려고 ZStack으로 나눠 둡니다.
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    PixelDetailHeroView(
                        photoURL: snapshot.destinationPhotoURL,
                        title: snapshot.title,
                        travelDate: snapshot.travelDate
                    )

                    sheet
                        // 시트가 사진 위로 올라와 둥근 모서리 안쪽에 사진이 비칩니다.
                        .padding(.top, -30)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)

            floatingBar
        }
        .background(PicselColor.surface)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }

    // MARK: - 기록 시트

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 32) {
            if !snapshot.memo.isEmpty {
                Text(snapshot.memo)
                    .font(PicselFont.body01)
                    .foregroundStyle(PicselColor.textSecondary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !stops.isEmpty {
                RouteTimelineView(stops: stops)
            }

            // 사진이 없으면 TripPhotoGrid가 아무것도 그리지 않아 섹션째 사라집니다.
            TripPhotoGrid(photoDataList: snapshot.photoDataList)
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PicselColor.surface,
            in: .rect(
                topLeadingRadius: 30,
                topTrailingRadius: 30
            )
        )
    }

    // MARK: - 사진 위에 뜨는 버튼

    private var floatingBar: some View {
        HStack {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PicselColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: .circle)
            }
            .accessibilityLabel("뒤로")

            Spacer()

            // TODO: Step 4 - 제목·내용·사진 인라인 편집
            Button {
            } label: {
                Text("편집")
                    .font(PicselFont.label01)
                    .foregroundStyle(PicselColor.textPrimary)
                    .frame(height: 44)
                    .padding(.horizontal, 20)
                    .background(.ultraThinMaterial, in: .capsule)
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview("사진 7장") {
    // 숫자만 바꿔 가며 0~10장 배치를 확인하세요.
    NavigationStack {
        PixelDetailView(snapshot: TripRecordPreviewData.snapshot(photoCount: 7))
    }
}

#Preview("사진 없음") {
    NavigationStack {
        PixelDetailView(snapshot: TripRecordPreviewData.snapshot(photoCount: 0))
    }
}
