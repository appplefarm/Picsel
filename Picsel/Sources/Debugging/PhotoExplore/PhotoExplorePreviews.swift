//
//  PhotoExplorePreviews.swift
//  Picsel
//

import SwiftUI

#if DEBUG
#Preview("Photo Explore") {
    PhotoExploreRootView(service: PreviewPhotoDestinationService())
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
