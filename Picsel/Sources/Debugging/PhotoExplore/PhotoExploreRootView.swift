//
//  PhotoExploreRootView.swift
//  Picsel
//

import SwiftUI

#if DEBUG
/// 다음 화면이 연결되기 전까지 PhotoExplore 기능을 독립 실행하는 컨테이너입니다.
struct PhotoExploreRootView: View {
    private let service: any PhotoDestinationService

    @State private var selectedDestination: PhotoDestination?

    init(
        service: any PhotoDestinationService = TourAPIPhotoDestinationService(
            configuration: .current
        )
    ) {
        self.service = service
    }

    var body: some View {
        NavigationStack {
            PhotoExploreView(service: service) { destination in
                selectedDestination = destination
            }
        }
        .alert(item: $selectedDestination) { destination in
            Alert(
                title: Text("\(destination.name)을(를) 선택했어요"),
                message: Text(selectionMessage(for: destination)),
                dismissButton: .default(Text("확인"))
            )
        }
    }

    private func selectionMessage(
        for destination: PhotoDestination
    ) -> String {
        if destination.placeDTO != nil {
            return "다음 목적지 플로우로 전달할 수 있습니다."
        }

        return "서버에서 주소와 좌표를 보강하면 PlaceDTO로 변환됩니다."
    }
}
#endif
