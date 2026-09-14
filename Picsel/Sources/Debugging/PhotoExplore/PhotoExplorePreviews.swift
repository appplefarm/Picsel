//
//  PhotoExplorePreviews.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

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
        .navigationTitle("사진으로 목적지 고르기")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview("Destination Detail") {
    DestinationDetailView(
        destination: PhotoDestination.previewSamples[0],
        info: DestinationDetailInfo(
            destination: PhotoDestination.previewSamples[0]
        )
    ) { }
    .background(PhotoExploreBackground())
}

#Preview("Interaction Settings") {
    @Previewable @State var settings = PhotoInteractionSettings.defaults

    PhotoInteractionSettingsPanel(settings: $settings)
}
#endif
