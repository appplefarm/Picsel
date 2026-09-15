//
//  TripPhotoImage.swift
//  Picsel
//
//  Created by kosoobin on 9/15/26.
//

import ImageIO
import UIKit

/// 기록 사진을 화면에 올리기 전에 크기를 재고 줄이는 도구입니다.
///
/// 사용자가 올린 사진은 한 장에 수 MB씩 되므로 UIImage(data:)로 통째로 펼치면
/// 사진 10장짜리 기록에서 스크롤이 끊깁니다.
/// ImageIO로 헤더만 읽어 크기를 재고, 화면에 필요한 만큼만 줄여서 펼칩니다.
enum TripPhotoImage {

    /// 사진의 가로세로비(가로 ÷ 세로)입니다. 픽셀을 펼치지 않고 헤더만 읽습니다.
    ///
    /// 세로로 찍은 사진은 파일 안에 가로로 저장되고 회전 정보만 따로 붙어 있어서,
    /// 회전 정보를 함께 보지 않으면 가로세로가 뒤집힌 값이 나옵니다.
    static func aspectRatio(of data: Data) -> CGFloat? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0 else { return nil }

        // EXIF 방향 5~8은 가로와 세로가 서로 바뀐 상태로 저장된 사진입니다.
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let isSwapped = (5...8).contains(orientation)

        return isSwapped ? height / width : width / height
    }

    /// 긴 변이 `maxPixelSize`가 되도록 줄여서 펼칩니다. 회전 정보도 함께 적용합니다.
    static func downsampled(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // 세로 사진이 눕지 않도록 회전 정보를 반영해서 만듭니다.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
