//
//  PhotoExplorePreviews.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import CoreLocation
import SwiftUI

#if DEBUG
#Preview("Photo Explore Loading") {
    PhotoExploreLoadingView()
        .preferredColorScheme(.light)
}

#Preview("Photo Explore Loading · Paused") {
    PhotoExploreLoadingView()
        .environment(\.scenePhase, .inactive)
        .preferredColorScheme(.light)
}

#Preview("Photo Explore Loading · Large Text") {
    PhotoExploreLoadingView()
        .environment(\.scenePhase, .inactive)
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.light)
}

#Preview("Photo Explore") {
    PhotoExploreRootView(service: PreviewPhotoDestinationService())
}

#Preview("Photo Explore · Loading → Explore") {
    PhotoExploreRootView(
        service: PreviewPhotoDestinationService(loadingDelay: .seconds(3))
    )
}

#Preview("Photo Explore Content") {
    NavigationStack {
        PhotoExploreView(service: PreviewPhotoDestinationService()) { _ in }
    }
}

#Preview("Spatial Photo Canvas") {
    NavigationStack {
        SpatialPhotoCanvas(
            destinations: PhotoDestination.previewSamples
        ) { _ in }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Destination Detail · 위치 정보 있음") {
    let destination = PhotoDestination(
        id: "preview-detail",
        name: "스페이스워크",
        photoURL: "https://tong.visitkorea.or.kr/cms2/website/08/2909208.jpg",
        address: "경상북도 포항시 북구",
        latitude: 36.0651092,
        longitude: 129.3904401
    )
    DestinationDetailView(
        destination: destination,
        originLocation: CLLocation(latitude: 36.013, longitude: 129.323),
        directionsService: PreviewDestinationDirectionsService()
    ) { }
    .background(PhotoExploreBackground())
}

#Preview("Destination Detail · 위치 정보 없음") {
    DestinationDetailView(
        destination: PhotoDestination.previewSamples[0]
    ) { }
    .background(PhotoExploreBackground())
}

#Preview("Destination Detail · 경로 조회 실패") {
    DestinationDetailView(
        destination: PhotoDestination(
            id: "preview-directions-failure",
            name: "스페이스워크",
            address: "경상북도 포항시 북구",
            latitude: 36.0651092,
            longitude: 129.3904401
        ),
        originLocation: CLLocation(latitude: 36.013, longitude: 129.323),
        directionsService: PreviewDestinationDirectionsService(shouldFail: true)
    ) { }
    .background(PhotoExploreBackground())
}

#Preview("Interaction Settings") {
    @Previewable @State var settings = PhotoInteractionSettings.defaults

    PhotoInteractionSettingsPanel(settings: $settings)
}

/// 프리뷰에서는 현재 위치·실제 지도 API를 사용하지 않습니다.
private struct PreviewDestinationDirectionsService: RouteDirectionsProviding {
    var shouldFail = false

    func directions(
        origin: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) async throws -> RouteDirections {
        try await Task.sleep(for: .milliseconds(500))
        if shouldFail { throw RouteDirectionsError.routeNotFound }
        return RouteDirections(distanceMeters: 62_000, duration: 4_200, path: [], legs: [])
    }
}
#endif
