//
//  PicselMapViewModel.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/1/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class PicselMapViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var regions: [AdministrativeRegion]
    private(set) var phase: Phase
    private(set) var selectedRegionCode: String?
    @ObservationIgnored private let repository: any AdministrativeRegionRepository

    init(
        regions: [AdministrativeRegion]? = nil,
        repository: any AdministrativeRegionRepository = BundledGeoJSONRegionRepository()
    ) {
        self.regions = regions ?? []
        self.phase = regions == nil ? .idle : .loaded
        self.repository = repository
    }

    var selectedRegion: AdministrativeRegion? {
        regions.first { $0.code == selectedRegionCode }
    }

    func loadRegions() async {
        guard phase != .loading, phase != .loaded else { return }
        phase = .loading

        let repository = repository
        let loadingTask = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            return try repository.loadRegions()
        }

        do {
            let loadedRegions = try await withTaskCancellationHandler {
                try await loadingTask.value
            } onCancel: {
                loadingTask.cancel()
            }
            try Task.checkCancellation()
            regions = loadedRegions
            phase = .loaded
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// 화면에 보여줄 기록입니다. 한 지역을 여러 번 여행했다면 그만큼 쌓입니다.
    ///
    /// 지역을 고르지 않았을 때는 전체를 최근 순으로 보여 줍니다.
    /// 정렬은 PicselMapScreen이 이미 최근 순으로 넘겨 주므로 여기서 다시 하지 않습니다.
    func displayedRecords(in records: [PicselMapRecord]) -> [PicselMapRecord] {
        guard let selectedRegion else { return records }
        return records.filter { selectedRegion.containsAnyRegion(in: [$0.regionCode]) }
    }

    func selectRegion(code: String?) {
        selectedRegionCode = selectedRegionCode == code ? nil : code
    }
}
