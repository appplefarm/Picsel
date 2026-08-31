//
//  PhotoDestinationService.swift
//  Picsel
//

import Foundation

/// 화면은 실제 API 구현을 모른 채 목적지 후보만 받습니다.
protocol PhotoDestinationService: Sendable {
    func fetchDestinations(limit: Int) async throws -> [PhotoDestination]
}
