//
//  RemotePhotoImageLoader.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import CoreGraphics
import Foundation
import ImageIO

/// 원격 사진을 화면 용도에 맞는 크기의 `CGImage`로 변환합니다.
enum RemotePhotoImageLoader {
    nonisolated private static let maximumTexturePixelSize = 1_600

    enum LoadError: Error {
        case invalidResponse
        case invalidImage
    }

    nonisolated static func image(from url: URL) async throws -> CGImage {
        try await image(from: url, maximumPixelSize: maximumTexturePixelSize)
    }

    nonisolated static func image(
        from url: URL,
        maximumPixelSize: Int
    ) async throws -> CGImage {
        let (data, response) = try await URLSession.shared.data(from: url)
        try Task.checkCancellation()

        if let response = response as? HTTPURLResponse,
           !(200..<300).contains(response.statusCode) {
            throw LoadError.invalidResponse
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw LoadError.invalidImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw LoadError.invalidImage
        }

        return image
    }
}
