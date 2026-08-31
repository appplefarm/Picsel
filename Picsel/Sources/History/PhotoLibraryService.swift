//
//  PhotoLibraryService.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import Photos
import UIKit

enum PhotoLibraryService {

    /// 권한 요청 후 현재 상태를 돌려준다
    static func requestAuthorization() async -> PHAuthorizationStatus {
        // TODO: Step 4 - PHPhotoLibrary.requestAuthorization(for: .readWrite)
        .notDetermined
    }

    /// 최신순으로 사진 에셋 목록 가져오기
    static func fetchAssets() -> [PHAsset] {
        // TODO: Step 4 - PHAsset.fetchAssets(with: .image, options:) + creationDate 내림차순
        []
    }

    /// PHAsset -> 화면에 그릴 이미지
    static func requestImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        // TODO: Step 4 - PHImageManager.default().requestImage
        nil
    }
}
