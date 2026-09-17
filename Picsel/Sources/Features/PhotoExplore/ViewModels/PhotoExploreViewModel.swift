//
//  PhotoExploreViewModel.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import Foundation
import Observation

/// 관광사진 목록의 로딩 상태만 관리합니다.
@MainActor
@Observable
final class PhotoExploreViewModel {
    enum Phase {
        case loading
        case loaded([PhotoDestination])
        case empty
        case failed(String)
    }

    private let service: any PhotoDestinationService

    private(set) var phase: Phase = .loading
    private(set) var loadRequest = 0

    init(service: any PhotoDestinationService) {
        self.service = service
    }

    func load() async {
        // 같은 탐색 세션으로 돌아오면 사진 순서와 캔버스 상태를 유지합니다.
        guard case .loading = phase else { return }

        do {
            let destinations = try await service.fetchDestinations(
                limit: SpatialPlaceItem.displayLimit
            )
            try Task.checkCancellation()

            phase = destinations.isEmpty ? .empty : .loaded(destinations)
        } catch is CancellationError {
            // 화면이 사라져 취소된 작업은 오류로 표시하지 않습니다.
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }

    func retry() {
        phase = .loading
        loadRequest += 1
    }
}
