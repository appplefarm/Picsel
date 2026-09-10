import Foundation

private struct FixtureClient: PhotoCatalogClient {
    let response: PhotoCatalogResponse
    func fetchCatalog() async throws -> PhotoCatalogResponse { response }
}

private struct FailingClient: PhotoCatalogClient {
    func fetchCatalog() async throws -> PhotoCatalogResponse { throw URLError(.notConnectedToInternet) }
}

private struct CheckFailed: Error { let message: String }

@main
struct ValidatePhotoCatalog {
    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count == 2,
              let bundle = Bundle(path: CommandLine.arguments[1]) else {
            throw CheckFailed(message: "Pass the built Picsel.app bundle path")
        }

        var checks = 0
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw CheckFailed(message: message) }
            checks += 1
        }

        let client = BundledPhotoCatalogClient(bundle: bundle)
        let response = try await client.fetchCatalog()
        let service = CatalogPhotoDestinationService(client: client)
        let all = try await service.fetchDestinations(limit: 30)
        let firstTen = try await service.fetchDestinations(limit: 10)

        try check(response.schemaVersion == 1 && response.photos.count == 19, "19 production records")
        try check(Set(response.photos.map(\.id)).count == 19, "stable distinct source-qualified IDs")
        try check(response.photos.allSatisfy { $0.sourceRegionCode == "47" && $0.regionCode == nil }, "province code not used as pixel code")
        try check(response.photos.allSatisfy(\.locationConfirmed), "production resource contains only reviewed records")
        try check(!response.photos.contains { $0.photoID == "3543624" }, "unverified fixture not packaged in production catalog")
        try check(all.count == 19 && all.allSatisfy(\.canSelectAsDestination), "every production destination is selectable")
        try check(firstTen.count == 10 && firstTen == Array(all.prefix(10)), "stable ten-photo display")
        try check(try await service.fetchDestinations(limit: 0).isEmpty, "zero limit")
        try check(try await service.fetchDestinations(limit: -1).isEmpty, "negative limit")
        try check(try await service.fetchDestinations(limit: 3).count == 3, "partial results")

        guard let canal = all.first(where: { $0.id == "tourPhotoGallery:2909171" }) else {
            throw CheckFailed(message: "Canal missing")
        }
        try check(canal.latitude == 36.031149 && canal.longitude == 129.372431, "edited worksheet coordinates preserved")
        try check(canal.placeDTO?.name == "포항운하" && canal.placeDTO?.photoURL == canal.photoURL, "existing PlaceDTO conversion")

        let baseData = try JSONEncoder().encode(response)
        func replacingFirst(_ key: String, with value: Any) throws -> PhotoCatalogResponse {
            var object = try JSONSerialization.jsonObject(with: baseData) as! [String: Any]
            var photos = object["photos"] as! [[String: Any]]
            photos[0][key] = value
            object["photos"] = photos
            return try JSONDecoder().decode(PhotoCatalogResponse.self, from: JSONSerialization.data(withJSONObject: object))
        }

        for (key, value) in [("latitude", 91.0), ("longitude", 181.0)] {
            let changed = try replacingFirst(key, with: value)
            let invalid = changed.photos[0].destination
            try check(!invalid.canSelectAsDestination && invalid.placeDTO == nil, "out-of-range \(key) cannot route")
            let filtered = try await CatalogPhotoDestinationService(client: FixtureClient(response: changed)).fetchDestinations(limit: 10)
            try check(filtered.count == 10 && !filtered.contains { $0.id == invalid.id }, "filter invalid \(key) before applying limit")
        }
        for (key, value) in [("latitude", NSNull() as Any), ("locationConfirmed", false as Any)] {
            let changed = try replacingFirst(key, with: value)
            let destinations = try await CatalogPhotoDestinationService(client: FixtureClient(response: changed)).fetchDestinations(limit: 30)
            try check(destinations.count == 18 && destinations.allSatisfy(\.canSelectAsDestination), "exclude invalid \(key)")
        }
        let missingAddress = try replacingFirst("address", with: NSNull()).photos[0].destination
        try check(missingAddress.canSelectAsDestination && missingAddress.placeDTO == nil, "valid coordinates usable without address")

        let badResponses = [
            PhotoCatalogResponse(schemaVersion: 2, photos: response.photos),
            PhotoCatalogResponse(schemaVersion: 1, photos: [response.photos[0], response.photos[0]]),
            try replacingFirst("photoURL", with: "not-a-url")
        ]
        for bad in badResponses {
            do {
                _ = try await CatalogPhotoDestinationService(client: FixtureClient(response: bad)).fetchDestinations(limit: 10)
                throw CheckFailed(message: "Invalid response accepted")
            } catch is CatalogPhotoDestinationService.CatalogError { checks += 1 }
        }

        let emptyResponse = PhotoCatalogResponse(schemaVersion: 1, photos: [])
        let emptyViewModel = PhotoExploreViewModel(service: CatalogPhotoDestinationService(client: FixtureClient(response: emptyResponse)))
        await emptyViewModel.load()
        if case .empty = emptyViewModel.phase { checks += 1 }
        else { throw CheckFailed(message: "Empty state") }
        let failedViewModel = PhotoExploreViewModel(service: CatalogPhotoDestinationService(client: FailingClient()))
        await failedViewModel.load()
        if case .failed = failedViewModel.phase { checks += 1 }
        else { throw CheckFailed(message: "Failure state") }
        failedViewModel.retry()
        try check(failedViewModel.loadRequest == 1, "retry starts a new view task")
        let loadedViewModel = PhotoExploreViewModel(service: service)
        await loadedViewModel.load()
        if case .loaded(let destinations) = loadedViewModel.phase {
            try check(destinations == firstTen, "existing ViewModel receives selectable photos")
        } else { throw CheckFailed(message: "Loaded state") }

        // No JSON is copied beside this CLI executable: test missing-resource handling.
        do {
            _ = try await BundledPhotoCatalogClient().fetchCatalog()
            throw CheckFailed(message: "Missing catalog ignored")
        } catch is BundledPhotoCatalogClient.CatalogFileError { checks += 1 }
        let cancelled = Task { try await client.fetchCatalog() }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            throw CheckFailed(message: "Cancellation ignored")
        } catch is CancellationError { checks += 1 }

        // Verify the actual factory, including Release ignoring every Debug override.
        let originalSource = ProcessInfo.processInfo.environment["PICSEL_PHOTO_SOURCE"]
        defer {
            if let originalSource { setenv("PICSEL_PHOTO_SOURCE", originalSource, 1) }
            else { unsetenv("PICSEL_PHOTO_SOURCE") }
        }
        unsetenv("PICSEL_PHOTO_SOURCE")
        let defaultPhotos = try await PhotoDestinationServiceFactory.make(bundle: bundle).fetchDestinations(limit: 10)
        try check(defaultPhotos == firstTen, "default factory uses production bundle")
        try check(PhotoDestinationServiceFactory.sourceNotice?.contains("설정 반경과 무관") == true, "disclose catalog scope")

#if DEBUG
        let validation = try await DebugPhotoCatalogClient(bundle: bundle, scenario: .validation, delay: .zero).fetchCatalog()
        let held = DebugPhotoCatalogClient.unverifiedPhoto
        try check(validation.photos.count == 20 && validation.photos[6].id == held.id, "original validation photo order preserved")
        try check(held.latitude == 36.2786758 && held.longitude == 129.2899056 && !held.locationConfirmed, "original unverified coordinates retained")
        try check(held.destination.latitude == nil && !held.destination.canSelectAsDestination, "validation detail cannot confirm destination")
        let validated = try await CatalogPhotoDestinationService(client: FixtureClient(response: validation)).fetchDestinations(limit: 10)
        try check(validated == firstTen, "validation fixture cannot leak into selectable catalog")
        let onlyHeld = PhotoCatalogResponse(schemaVersion: 1, photos: [held])
        let heldViewModel = PhotoExploreViewModel(service: CatalogPhotoDestinationService(client: FixtureClient(response: onlyHeld)))
        await heldViewModel.load()
        if case .empty = heldViewModel.phase { checks += 1 }
        else { throw CheckFailed(message: "All unverified records should become empty state") }

        setenv("PICSEL_PHOTO_SOURCE", "empty", 1)
        try check(try await PhotoDestinationServiceFactory.make(bundle: bundle).fetchDestinations(limit: 10).isEmpty, "Debug empty override")
        setenv("PICSEL_PHOTO_SOURCE", "failure", 1)
        do {
            _ = try await PhotoDestinationServiceFactory.make(bundle: bundle).fetchDestinations(limit: 10)
            throw CheckFailed(message: "Debug failure override ignored")
        } catch is URLError { checks += 1 }
        let pending = Task { try await DebugPhotoCatalogClient(bundle: bundle, delay: .seconds(5)).fetchCatalog() }
        pending.cancel()
        do {
            _ = try await pending.value
            throw CheckFailed(message: "Delayed cancellation ignored")
        } catch is CancellationError { checks += 1 }
        let configuration = "Debug"
#else
        for source in ["empty", "failure", "slow", "tourAPI"] {
            setenv("PICSEL_PHOTO_SOURCE", source, 1)
            let photos = try await PhotoDestinationServiceFactory.make(bundle: bundle).fetchDestinations(limit: 10)
            try check(photos == firstTen, "Release ignores \(source) override")
        }
        let configuration = "Release"
#endif

        print("PASS: \(checks) \(configuration) checks; 19 catalog records, 10 selectable destinations")
    }
}
