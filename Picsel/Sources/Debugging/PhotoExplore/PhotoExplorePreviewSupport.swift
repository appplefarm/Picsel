//
//  PhotoExplorePreviewSupport.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import Foundation

#if DEBUG
/// Xcode Preview에서만 사용하는 장소와 서비스입니다.
extension PhotoDestination {
    static let previewSamples: [PhotoDestination] = [
        .preview(id: "preview-1", name: "호미곧 해맞이광장"),
        .preview(id: "preview-2", name: "구룡포 일본인가옥거리"),
        .preview(id: "preview-3", name: "월포해수욕장"),
        .preview(id: "preview-4", name: "오어사"),
        .preview(id: "preview-5", name: "포항 운하"),
        .preview(id: "preview-6", name: "이가리 닻 전망대"),
        .preview(id: "preview-7", name: "영일대해수욕장"),
        .preview(id: "preview-8", name: "환호공원"),
        .preview(id: "preview-9", name: "내연산"),
        .preview(id: "preview-10", name: "포항 스페이스워크")
    ]

    private static func preview(
        id: String,
        name: String
    ) -> PhotoDestination {
        PhotoDestination(
            id: id,
            name: name
        )
    }
}

struct PreviewPhotoDestinationService: PhotoDestinationService {
    var destinations: [PhotoDestination] = PhotoDestination.previewSamples
    var loadingDelay: Duration = .zero

    func fetchDestinations(limit: Int) async throws -> [PhotoDestination] {
        try await Task.sleep(for: loadingDelay)
        return Array(destinations.prefix(limit))
    }
}
#endif
