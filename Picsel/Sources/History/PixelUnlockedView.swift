//
//  PixelUnlockedView.swift
//  Picsel
//
//  18_픽셀_획득 — "새로운 픽셀이 채워졌어요!"
//  저장 직후 결과 화면.
//

import SwiftUI

struct PixelUnlockedView: View {

    let snapshot: TripRecordSnapshot

    @State private var isPixelDetailPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새로운 픽셀이 채워졌어요!")
                .font(.title)
                .fontWeight(.bold)

            Text("\(snapshot.regionName) 여행이 나의 픽셀 지도에 기록됐어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // TODO: 픽셀맵 연결 시 실제 지도로 교체 (팀원 파트)
            Group {
                if let data = snapshot.representativePhotoData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray.opacity(0.2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            TripSummaryCard(
                thumbnailData: snapshot.representativePhotoData,
                travelDate: snapshot.travelDate,
                title: snapshot.title,
                photoCount: snapshot.photoCount,
                placeCount: snapshot.placeCount
            )

            Spacer()

            Button {
                // TODO: 홈 탭으로 이동 (탭 구조 붙은 뒤 연결)
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
                isPixelDetailPresented = true
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
        .navigationDestination(isPresented: $isPixelDetailPresented) {
            PixelDetailView(snapshot: snapshot)
        }
    }
}

#Preview {
    NavigationStack {
        PixelUnlockedView(snapshot: .sample)
    }
}
