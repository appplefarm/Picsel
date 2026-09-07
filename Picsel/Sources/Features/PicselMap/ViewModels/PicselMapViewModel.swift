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

    func displayedRecord(in records: [PicselMapRecord]) -> PicselMapRecord? {
        guard let selectedRegion else { return records.first }
        return records.first { selectedRegion.containsAnyRegion(in: [$0.regionCode]) }
    }

    func selectRegion(code: String?) {
        selectedRegionCode = selectedRegionCode == code ? nil : code
    }
}
