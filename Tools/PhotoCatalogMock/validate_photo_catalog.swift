import Foundation

private struct FixtureClient: PhotoCatalogClient {
    let response: PhotoCatalogResponse
    func fetchCatalog() async throws -> PhotoCatalogResponse { response }
}

private struct CheckFailed: Error { let message: String }

@MainActor
private final class CountingService: PhotoDestinationService {
    let destinations: [PhotoDestination]
    private(set) var calls = 0

    init(destinations: [PhotoDestination]) { self.destinations = destinations }

    func fetchDestinations(limit: Int) async throws -> [PhotoDestination] {
        calls += 1
        return Array(destinations.prefix(limit))
    }
}

@main
struct ValidatePhotoCatalog {
    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count == 2,
              let bundle = Bundle(path: CommandLine.arguments[1]) else {
            throw CheckFailed(message: "Pass the built Picsel.app or a fixture bundle path")
        }

        var checks = 0
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw CheckFailed(message: message) }
            checks += 1
        }

        let client = BundledPhotoCatalogClient(bundle: bundle, delay: .zero)
        let response = try await client.fetchCatalog()
        let service = CatalogPhotoDestinationService(client: client)

        try check(response.schemaVersion == 1 && response.photos.count == 20, "20 source records")
        try check(Set(response.photos.map(\.id)).count == 20, "stable distinct source-qualified IDs")
        try check(response.photos.allSatisfy { $0.sourceRegionCode == "47" && $0.regionCode == nil }, "province code not used as pixel code")

        let all = try await service.fetchDestinations(limit: 30)
        try check(all.count == 20, "all 20 photos are retained")
        try check(all.filter(\.canSelectAsDestination).count == 19, "only 19 locations may route")
        let firstTen = try await service.fetchDestinations(limit: 10)
        try check(firstTen.map(\.id) == Array(all.prefix(10)).map(\.id), "deterministic display limit")
        try check(try await service.fetchDestinations(limit: 0).isEmpty, "zero limit")
        try check(try await service.fetchDestinations(limit: -1).isEmpty, "negative limit")
        try check(try await service.fetchDestinations(limit: 3).count == 3, "partial results")

        guard let held = response.photos.first(where: { $0.photoID == "3543624" }) else {
            throw CheckFailed(message: "Naeyeonsan validation record missing")
        }
        try check(!held.locationConfirmed && held.latitude != nil && held.longitude != nil, "raw unverified coordinates preserved")
        try check(firstTen.contains { $0.id == held.id }, "Naeyeonsan visible in first ten")
        try check(held.destination.latitude == nil && !held.destination.canSelectAsDestination && held.destination.placeDTO == nil, "unverified photo cannot route")
        guard let canal = all.first(where: { $0.id == "tourPhotoGallery:2909171" }) else {
            throw CheckFailed(message: "Canal missing")
        }
        try check(canal.latitude == 36.031149 && canal.longitude == 129.372431, "edited worksheet coordinates used instead of base coordinates")
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
            let invalid = try replacingFirst(key, with: value).photos[0].destination
            try check(!invalid.canSelectAsDestination && invalid.placeDTO == nil, "out of range \(key) cannot route")
        }
        let missingCoordinate = try replacingFirst("latitude", with: NSNull()).photos[0].destination
        try check(!missingCoordinate.canSelectAsDestination, "missing coordinates cannot route")
        let missingAddress = try replacingFirst("address", with: NSNull()).photos[0].destination
        try check(missingAddress.canSelectAsDestination && missingAddress.placeDTO == nil, "valid coordinates remain usable without an address")

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

        let empty = CatalogPhotoDestinationService(client: BundledPhotoCatalogClient(bundle: bundle, scenario: .empty, delay: .zero))
        let failed = CatalogPhotoDestinationService(client: BundledPhotoCatalogClient(bundle: bundle, scenario: .failure, delay: .zero))
        let emptyViewModel = PhotoExploreViewModel(service: empty)
        await emptyViewModel.load()
        if case .empty = emptyViewModel.phase { checks += 1 }
        else { throw CheckFailed(message: "Empty state") }
        let failedViewModel = PhotoExploreViewModel(service: failed)
        await failedViewModel.load()
        if case .failed = failedViewModel.phase { checks += 1 }
        else { throw CheckFailed(message: "Failure state") }
        failedViewModel.retry()
        try check(failedViewModel.loadRequest == 1, "retry starts a new view task")
        let loadedViewModel = PhotoExploreViewModel(service: service)
        await loadedViewModel.load()
        if case .loaded(let destinations) = loadedViewModel.phase {
            try check(destinations.count == SpatialPlaceItem.displayLimit, "existing ViewModel receives ten photos")
        } else { throw CheckFailed(message: "Loaded state") }

        let counting = CountingService(destinations: all)
        let session = PhotoExploreViewModel(service: counting)
        await session.load()
        await session.load()
        try check(counting.calls == 1, "returning to exploration does not refetch")
        if case .loaded(let photos) = session.phase {
            try check(photos.map(\.id) == Array(all.prefix(SpatialPlaceItem.displayLimit)).map(\.id), "photo order survives return")
        } else { throw CheckFailed(message: "Return lost loaded state") }
        session.retry()
        if case .loading = session.phase { checks += 1 }
        else { throw CheckFailed(message: "Retry must reenter loading") }
        await session.load()
        try check(counting.calls == 2, "explicit retry refetches")
        await PhotoExploreViewModel(service: counting).load()
        try check(counting.calls == 3, "new exploration refetches")

        let pending = Task { try await BundledPhotoCatalogClient(bundle: bundle, delay: .seconds(5)).fetchCatalog() }
        pending.cancel()
        do {
            _ = try await pending.value
            throw CheckFailed(message: "Cancellation ignored")
        } catch is CancellationError { checks += 1 }

        print("PASS: \(checks) checks; 20 response photos, 19 routable locations, Naeyeonsan retained for validation")
    }
}
