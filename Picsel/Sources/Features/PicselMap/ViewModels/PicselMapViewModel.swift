//
//  PicselMapViewModel.swift
//  Picsel
//
//  Created by JonghyeonLee on 9/1/26.
//

import Observation

@MainActor
@Observable
final class PicselMapViewModel {
    private(set) var regions: [AdministrativeRegion]
    private(set) var unlockedRegionCodes: Set<String>
    private(set) var selectedRegionCode: String?

    init(
        regions: [AdministrativeRegion],
        unlockedRegionCodes: Set<String> = []
    ) {
        self.regions = regions
        self.unlockedRegionCodes = unlockedRegionCodes
    }

    var selectedRegion: AdministrativeRegion? {
        regions.first { $0.code == selectedRegionCode }
    }

    var isSelectedRegionUnlocked: Bool {
        guard let selectedRegion else { return false }
        return selectedRegion.containsAnyRegion(in: unlockedRegionCodes)
    }

    func selectRegion(code: String?) {
        selectedRegionCode = selectedRegionCode == code ? nil : code
    }
}
