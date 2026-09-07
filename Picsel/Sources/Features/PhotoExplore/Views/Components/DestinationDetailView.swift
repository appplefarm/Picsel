//
//  DestinationDetailView.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import CoreGraphics
import Foundation
import SwiftUI

/// 선택된 사진을 최종 목적지로 확정하기 전 보여주는 전체 화면 상세입니다.
struct DestinationDetailView: View {
    let destination: PhotoDestination
    let info: DestinationDetailInfo
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var loadedPhoto: CGImage?
    @State private var didFailToLoadPhoto = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()

                RadialGradient(
                    stops: [
                        .init(color: .white.opacity(0.22), location: 0),
                        .init(color: .clear, location: 0.58),
                        .init(color: .black.opacity(0.22), location: 1)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.44),
                    startRadius: 18,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.72
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    closeButton

                    Spacer(minLength: max(28, geometry.size.height * 0.07))

                    destinationPhoto(
                        maxWidth: min(342, geometry.size.width - 32),
                        maxHeight: 310
                    )

                    optionalDetails
                        .padding(.top, 10)

                    Spacer(minLength: 24)

                    Text("이 사진을 목적지로 선택하면 출발지와 목적지 사이에서 들를 만한 경유지를 찾아드려요.")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 326, alignment: .leading)

                    Button("최종 목적지로 선택하기") {
                        dismiss()
                        onConfirm()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .tint(Color(.darkGray))
                    .frame(maxWidth: 292, minHeight: 62)
                    .padding(.top, 48)
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .presentationBackground(.clear)
        .task(id: destination.photoURL) {
            await loadPhoto()
        }
    }

    private var closeButton: some View {
        HStack {
            Button("닫기", systemImage: "xmark", action: dismiss.callAsFunction)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.title3)
                .bold()
                .foregroundStyle(.gray)
                .frame(width: 44, height: 44)

            Spacer()
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func destinationPhoto(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        if let loadedPhoto {
            let size = fittedSize(
                for: loadedPhoto,
                maxWidth: maxWidth,
                maxHeight: maxHeight
            )

            Image(decorative: loadedPhoto, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .background(Color(.systemBackground))
                .clipShape(.rect(cornerRadius: 10))
                .accessibilityLabel(destination.name)
        } else if didFailToLoadPhoto {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(width: maxWidth, height: maxHeight)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 10))
                .accessibilityLabel("사진을 불러오지 못했습니다")
        } else {
            ProgressView()
                .frame(width: maxWidth, height: maxHeight)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 10))
                .accessibilityLabel("사진 불러오는 중")
        }
    }

    private func fittedSize(
        for image: CGImage,
        maxWidth: CGFloat,
        maxHeight: CGFloat
    ) -> CGSize {
        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height)

        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    private func loadPhoto() async {
        loadedPhoto = nil
        didFailToLoadPhoto = false

        guard let photoURL = destination.photoURL,
              let imageURL = URL(string: photoURL) else {
            didFailToLoadPhoto = true
            return
        }

        do {
            let image = try await RemotePhotoImageLoader.image(
                from: imageURL,
                maximumPixelSize: 2_400
            )
            try Task.checkCancellation()
            loadedPhoto = image
        } catch is CancellationError {
            return
        } catch {
            didFailToLoadPhoto = true
        }
    }

    @ViewBuilder
    private var optionalDetails: some View {
        if info.locationName != nil || !info.chips.isEmpty {
            VStack(spacing: 16) {
                if let locationName = info.locationName {
                    Text(locationName)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }

                if !info.chips.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(info.chips, id: \.self) { chip in
                            Text(chip)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(Color(.label))
                                .padding(.horizontal, 14)
                                .frame(height: 30)
                                .background(Color(.systemBackground), in: .capsule)
                        }
                    }
                }
            }
        }
    }
}
