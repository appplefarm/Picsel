//
//  RemotePlacePhoto.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/17/26.
//

import SwiftUI

/// 경유지 선택/경로 확인/여행 진행 화면에서 사용하는 경량 사진 표시와 재시도입니다.
struct RemotePlacePhoto: View {
    let url: URL?
    var tripID: UUID? = nil
    var compact = false
    @State private var image: UIImage?
    @State private var failure: RequestFailure?
    @State private var attempt = 0

    private struct RequestID: Equatable {
        let url: URL?
        let tripID: UUID?
        let attempt: Int
    }

    var body: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if url == nil {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("사진 없음")
                } else if let failure {
                    Button { attempt += 1 } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            if !compact {
                                Text(failure.retriesOnReconnect ? "사진 연결 실패 · 다시 시도" : "사진을 불러오지 못했어요 · 다시 시도")
                                    .font(PicselFont.caption01)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(8)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("사진 다시 불러오기")
                } else {
                    ProgressView().controlSize(compact ? .small : .regular)
                }
            }
            .clipped()
            .task(id: RequestID(url: url, tripID: tripID, attempt: attempt)) {
                image = nil
                failure = nil
                guard let url else { return }
                do {
                    let data = try await TripImageStore.shared.data(for: url, tripID: tripID)
                    try Task.checkCancellation()
                    guard let decoded = UIImage(data: data) else { throw RequestFailure.invalidResponse }
                    image = decoded
                } catch {
                    guard !Task.isCancelled, !RequestFailure.isCancellation(error) else { return }
                    failure = RequestFailure(error)
                }
            }
            .onNetworkRecovery {
                if failure?.retriesOnReconnect == true { attempt += 1 }
            }
    }
}
