// Offline regression checks. No real API keys, requests, or user stores are used.
import CoreLocation
import CryptoKit
import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers

// Only unrelated SDK/pixel presentation dependencies are stubbed; tested models are production code.
struct RouteMapMarker {
    enum Kind { case origin, waypoint, destination }
    let coordinate: CLLocationCoordinate2D
    let title: String
    let kind: Kind
}
struct TestPixel { let code: String }
extension Trip { var pixelTile: TestPixel? { nil } }
struct KakaoDirectionsService: RouteDirectionsProviding {
    func directions(origin: CLLocationCoordinate2D, waypoints: [CLLocationCoordinate2D], destination: CLLocationCoordinate2D) async throws -> RouteDirections {
        fatalError("Tests must inject their directions service")
    }
}

nonisolated final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: ((URLRequest) throws -> (Int, Data))?
    nonisolated(unsafe) private static var count = 0
    static var requests: Int { lock.withLock { count } }
    static func respond(_ callback: @escaping (URLRequest) throws -> (Int, Data)) {
        lock.withLock { handler = callback; count = 0 }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let callback = Self.lock.withLock { Self.count += 1; return Self.handler! }
        do {
            let (status, data) = try callback(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class DirectionsFixture: RouteDirectionsProviding {
    var error: Error?
    var requests = 0
    var delayed = false
    func directions(origin: CLLocationCoordinate2D, waypoints: [CLLocationCoordinate2D], destination: CLLocationCoordinate2D) async throws -> RouteDirections {
        requests += 1
        if delayed { try await Task.sleep(for: .milliseconds(80)) }
        if let error { throw error }
        return RouteDirections(distanceMeters: Int(origin.latitude * 100), duration: 600, path: [origin, destination], legs: [])
    }
}

@main
struct Checks {
    static var count = 0
    struct Failed: Error { let message: String }
    static func check(_ value: Bool, _ message: String) throws {
        guard value else { throw Failed(message: message) }
        count += 1
    }
    static func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !condition() {
            guard ContinuousClock.now < deadline else { throw Failed(message: "Fixture did not start") }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    static func main() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        try await checkRecommendations(session)
        try await checkRoutes()
        try await checkCache(session)
        try await checkDestinationDetail()
        try await checkExploreImages(session)
        print("PASS: \(count) network/retry/cache checks (zero real API requests)")
    }

    static func checkRecommendations(_ session: URLSession) async throws {
        try check(RequestFailure(URLError(.notConnectedToInternet)) == .offline, "Offline classification")
        try check(RequestFailure(URLError(.timedOut)) == .timedOut, "Timeout classification")
        try check(RequestFailure(URLError(.networkConnectionLost)).retriesOnReconnect, "Lost connection retries")
        try check(!RequestFailure.configuration.retriesOnReconnect, "Invalid key must not auto-loop")
        try check(RequestFailure.isCancellation(URLError(.cancelled)), "Cancellation is not a visible error")
        let service = TourAPIManager(session: session, serviceKey: "test%2Bkey%2F%3D")
        let empty = #"{"response":{"header":{"resultCode":"0000","resultMsg":"OK"},"body":{"items":"","totalCount":0,"numOfRows":100,"pageNo":1}}}"#
        StubURLProtocol.respond { request in
            let key = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "serviceKey" }?.value
            guard key == "test+key/=", request.url!.absoluteString.contains("%2B"), request.timeoutInterval == 20 else {
                throw Failed(message: "Query encoding/timeout")
            }
            return (200, Data(empty.utf8))
        }
        let result = try await service.fetchRecommendedPlaces(areaCode: "35", sigunguCode: "11")
        try check(result.isEmpty, "Successful empty API response")

        let vm = TransitSwipeViewModel(trip: Trip(), service: service)
        StubURLProtocol.respond { _ in throw URLError(.cancelled) }
        await vm.fetchRecommendedPlaces(areaCode: "35", sigunguCode: "11")
        if case .idle = vm.loadState { count += 1 }
        else { throw Failed(message: "Cancelled recommendations must remain retryable without error") }
        StubURLProtocol.respond { _ in throw URLError(.notConnectedToInternet) }
        await vm.fetchRecommendedPlaces(areaCode: "35", sigunguCode: "11")
        if case .failed(.offline) = vm.loadState { count += 1 }
        else { throw Failed(message: "Offline must not be an empty recommendation") }

        for (status, body, expected) in [
            (503, "{}", RequestFailure.server),
            (200, #"{"response":{"header":{"resultCode":"30","resultMsg":"ERROR"}}}"#, .server),
            (200, "not json", .invalidResponse),
            (200, empty.replacingOccurrences(of: "\"totalCount\":0", with: "\"totalCount\":1"), .invalidResponse)
        ] {
            StubURLProtocol.respond { _ in (status, Data(body.utf8)) }
            await vm.fetchRecommendedPlaces(areaCode: "35", sigunguCode: "11")
            if case .failed(let failure) = vm.loadState { try check(failure == expected, "API error classification") }
            else { throw Failed(message: "API error misclassified as empty") }
        }

        let valid = #"{"response":{"header":{"resultCode":"0000","resultMsg":"OK"},"body":{"items":{"item":[{"title":"A","contentid":"1","firstimage":"http://example.test/1.jpg"},{"title":"B","contentid":"2","firstimage":"https://example.test/2.jpg"}]},"totalCount":2,"numOfRows":100,"pageNo":1}}}"#
        StubURLProtocol.respond { _ in (200, Data(valid.utf8)) }
        await vm.fetchRecommendedPlaces(areaCode: "35", sigunguCode: "11")
        try check(vm.candidates.count == 2, "Retry succeeds")
        let selected = vm.candidates[0]
        vm.swipeRight(on: selected)
        vm.swipeLeft(on: vm.candidates[0])
        await vm.fetchRecommendedPlaces(areaCode: "35", sigunguCode: "11")
        try check(vm.selectedPlaces == [selected] && vm.candidates.isEmpty, "Return/reconnect preserves selections and dismissed cards")
        try check(StubURLProtocol.requests == 1, "No duplicate API call for loaded recommendations")
        let missingKey = TourAPIManager(session: session, serviceKey: "")
        do {
            _ = try await missingKey.fetchRecommendedPlaces(areaCode: "35", sigunguCode: "11")
            throw Failed(message: "Missing API key accepted")
        } catch let error as RequestFailure { try check(error == .configuration, "Missing key reports error, not fatalError") }
    }

    static func checkRoutes() async throws {
        let trip = Trip()
        trip.stops = [RouteStop(name: "Destination", latitude: 36, longitude: 129, stopType: "destination", orderIndex: 0)]
        let service = DirectionsFixture()
        let vm = RouteConfirmationViewModel(trip: trip, directionsService: service)
        await vm.loadDirections(origin: nil)
        try check(vm.needsOrigin && !vm.isLoadingDirections && service.requests == 0, "Missing origin is not infinite loading")
        let origin = CLLocationCoordinate2D(latitude: 35, longitude: 129)
        service.error = RouteDirectionsError.networkFailure(underlying: URLError(.timedOut))
        await vm.loadDirections(origin: origin)
        try check(vm.directionsFailure == .timedOut && !vm.isLoadingDirections, "Route timeout is retryable and ends loading")
        service.error = nil
        await vm.loadDirections(origin: origin)
        try check(vm.directions != nil && vm.directionsFailure == nil, "Route retry clears failure")
        await vm.loadDirections(origin: origin)
        try check(service.requests == 2, "Same successful route not requested twice")

        service.delayed = true
        let old = Task { await vm.loadDirections(origin: .init(latitude: 34, longitude: 129)) }
        try await waitUntil { service.requests == 3 }
        let new = Task { await vm.loadDirections(origin: .init(latitude: 33, longitude: 129)) }
        await old.value
        await new.value
        try check(vm.directions?.distanceMeters == 3300, "Old route response cannot overwrite new route")
        let cancelled = Task { await vm.loadDirections(origin: .init(latitude: 32, longitude: 129)) }
        try await waitUntil { service.requests == 5 }
        cancelled.cancel()
        vm.cancelDirections()
        await cancelled.value
        try check(!vm.isLoadingDirections && vm.directionsFailure == nil, "Navigating away cancels without error")
        await vm.loadDirections(origin: .init(latitude: 32, longitude: 129))
        try check(vm.directions?.distanceMeters == 3200, "Cancelled route can load when returning")
    }

    static func checkDestinationDetail() async throws {
        let destination = PhotoDestination(id: "photo", name: "Destination", latitude: 36, longitude: 129)
        let service = DirectionsFixture()
        let vm = DestinationDetailViewModel(destination: destination, directionsService: service)
        let origin = CLLocation(latitude: 35, longitude: 129)
        await vm.loadTravelInfo(from: nil)
        vm.retryAfterReconnection()
        if case .unavailable = vm.travelState {
            try check(service.requests == 0 && vm.retryAttempt == 0, "Missing location is not a network error")
        } else { throw Failed(message: "Missing location must remain unavailable") }

        for (error, expected) in [
            (RouteDirectionsError.networkFailure(underlying: URLError(.notConnectedToInternet)), RequestFailure.offline),
            (.networkFailure(underlying: URLError(.timedOut)), .timedOut),
            (.networkFailure(underlying: URLError(.networkConnectionLost)), .connection),
            (.missingAPIKey, .configuration),
            (.routeNotFound, .unavailable),
            (.providerError(code: "500", message: "private provider detail"), .server)
        ] {
            service.error = error
            await vm.loadTravelInfo(from: origin)
            guard case .failed(let failure) = vm.travelState else { throw Failed(message: "Detail must show failure") }
            try check(failure == expected, "Detail route error classification")
            let before = vm.retryAttempt
            vm.retryAfterReconnection()
            try check(vm.retryAttempt == before + (expected.retriesOnReconnect ? 1 : 0), "Only connection failures trigger detail retry")
        }
        service.error = nil
        await vm.loadTravelInfo(from: origin)
        guard case .loaded(let info) = vm.travelState else { throw Failed(message: "Detail retry must recover") }
        try check(info.distanceKilometers == 3.5 && info.estimatedDurationMinutes == 10, "Detail shows real distance and duration")
        let attempts = vm.retryAttempt, requests = service.requests
        vm.retryAfterReconnection()
        try check(vm.retryAttempt == attempts && service.requests == requests, "Reconnect preserves successful detail route")
        try check(destination.canSelectAsDestination, "Destination eligibility does not depend on network")

        service.error = RouteDirectionsError.networkFailure(underlying: URLError(.cancelled))
        await vm.loadTravelInfo(from: origin)
        if case .failed = vm.travelState { throw Failed(message: "Wrapped cancellation must not show detail error") }
        count += 1
        service.error = nil
        service.delayed = true
        let old = Task { await vm.loadTravelInfo(from: CLLocation(latitude: 34, longitude: 129)) }
        try await waitUntil { service.requests == requests + 2 }
        let new = Task { await vm.loadTravelInfo(from: CLLocation(latitude: 33, longitude: 129)) }
        await old.value
        await new.value
        guard case .loaded(let newest) = vm.travelState else { throw Failed(message: "Latest detail route must load") }
        try check(newest.distanceKilometers == 3.3, "Old detail response cannot overwrite new location")
    }

    static func checkExploreImages(_ session: URLSession) async throws {
        let pixel = CGContext(data: nil, width: 3_000, height: 1_500, bitsPerComponent: 8, bytesPerRow: 12_000,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!.makeImage()!
        let bytes = NSMutableData()
        let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, pixel, nil)
        CGImageDestinationFinalize(destination)
        let fixture = bytes as Data
        let loader = RemotePhotoImageLoader(session: session)
        let url = URL(string: "https://example.test/explore.jpg")!
        StubURLProtocol.respond { request in
            guard request.timeoutInterval == 20 else { throw Failed(message: "Explore image timeout") }
            return (200, fixture)
        }
        async let texture = loader.image(from: url, maximumPixelSize: 1_600)
        async let detail = loader.image(from: url, maximumPixelSize: 2_400)
        let (a, b) = try await (texture, detail)
        try check(StubURLProtocol.requests == 1, "Explore/detail share one download")
        try check(a.width == 1_600 && a.height == 800 && b.width == 2_400 && b.height == 1_200,
                  "Explore and detail retain resolution and aspect ratio")
        StubURLProtocol.respond { _ in throw URLError(.notConnectedToInternet) }
        let offline = try await loader.image(from: url, maximumPixelSize: 2_400)
        try check(offline.width == 2_400 && StubURLProtocol.requests == 0, "Offline detail reuses loaded explore photo")

        let uncached = URL(string: "https://example.test/new.jpg")!
        do {
            _ = try await loader.image(from: uncached, maximumPixelSize: 2_400)
            throw Failed(message: "Uncached offline photo must report failure")
        } catch let error as URLError { try check(RequestFailure(error) == .offline, "Uncached photo reports offline") }
        StubURLProtocol.respond { _ in (503, Data()) }
        do {
            _ = try await loader.image(from: uncached, maximumPixelSize: 2_400)
            throw Failed(message: "Image HTTP error accepted")
        } catch let failure as RequestFailure { try check(failure == .server, "Image HTTP error is distinct from offline") }
        StubURLProtocol.respond { _ in (200, Data("not an image".utf8)) }
        do {
            _ = try await loader.image(from: uncached, maximumPixelSize: 2_400)
            throw Failed(message: "Invalid image accepted")
        } catch let failure as RequestFailure { try check(failure == .invalidResponse, "Broken photo is not cached") }
        StubURLProtocol.respond { _ in (200, fixture) }
        let recovered = try await loader.image(from: uncached, maximumPixelSize: 2_400)
        try check(recovered.width == 2_400 && StubURLProtocol.requests == 1, "Failed image can retry successfully")

        let late = URL(string: "https://example.test/shared.jpg")!
        let gate = DispatchSemaphore(value: 0)
        defer { gate.signal() }
        StubURLProtocol.respond { _ in
            guard gate.wait(timeout: .now() + 3) == .success else { throw Failed(message: "Explore gate timed out") }
            return (200, fixture)
        }
        let cancelled = Task { try await loader.image(from: late, maximumPixelSize: 1_600) }
        try await waitUntil { StubURLProtocol.requests == 1 }
        let remaining = Task { try await loader.image(from: late, maximumPixelSize: 2_400) }
        cancelled.cancel()
        gate.signal()
        do {
            _ = try await cancelled.value
            throw Failed(message: "Cancelled image must not be applied")
        } catch is CancellationError { count += 1 }
        let image = try await remaining.value
        try check(image.width == 2_400 && StubURLProtocol.requests == 1, "Cancelling explore does not cancel shared detail download")
    }

    static func checkCache(_ session: URLSession) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PicselNetworkChecks-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let tripA = UUID(), tripB = UUID()
        let url = URL(string: "https://example.test/photo.jpg")!
        let pixel = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!.makeImage()!
        let bytes = NSMutableData()
        let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, pixel, nil)
        CGImageDestinationFinalize(destination)
        let fixture = bytes as Data
        StubURLProtocol.respond { _ in (200, fixture) }
        let store = TripImageStore(root: root, session: session)
        async let first = store.data(for: url, tripID: tripA)
        async let second = store.data(for: url, tripID: tripB)
        let (a, b) = try await (first, second)
        try check(!a.isEmpty && a == b && StubURLProtocol.requests == 1, "Concurrent image requests are deduplicated")
        let folderA = root.appendingPathComponent(tripA.uuidString)
        let folderB = root.appendingPathComponent(tripB.uuidString)
        try check(FileManager.default.fileExists(atPath: folderA.path), "Selected trip image persisted")
        try check(try folderA.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true, "Temporary images excluded from backup")
        StubURLProtocol.respond { _ in throw URLError(.notConnectedToInternet) }
        let relaunched = TripImageStore(root: root, session: session)
        let restored = try await relaunched.data(for: url, tripID: tripA)
        try check(restored == a && StubURLProtocol.requests == 0, "Offline/relaunch reads persisted photo without network")
        await store.removeTrip(tripA)
        _ = try await store.data(for: url, tripID: tripA)
        try check(!FileManager.default.fileExists(atPath: folderA.path), "Completed trip cache is not recreated")
        try check(FileManager.default.fileExists(atPath: folderB.path), "Cleanup preserves another trip's photos")
        let cachedFile = try FileManager.default.contentsOfDirectory(at: folderB, includingPropertiesForKeys: nil)[0]
        try Data("broken".utf8).write(to: cachedFile)
        StubURLProtocol.respond { _ in (200, fixture) }
        _ = try await relaunched.data(for: url, tripID: tripB)
        try check(StubURLProtocol.requests == 1, "Corrupted disk image is fetched again")
        await store.removeTrip(tripB)

        let tripC = UUID()
        let gate = DispatchSemaphore(value: 0)
        defer { gate.signal() }
        StubURLProtocol.respond { _ in
            guard gate.wait(timeout: .now() + 3) == .success else { throw Failed(message: "Download gate timed out") }
            return (200, fixture)
        }
        let inFlight = Task { try await store.data(for: URL(string: "https://example.test/late.jpg")!, tripID: tripC) }
        try await waitUntil { StubURLProtocol.requests == 1 }
        await store.removeTrip(tripC)
        gate.signal()
        _ = try await inFlight.value
        try check(!FileManager.default.fileExists(atPath: root.appendingPathComponent(tripC.uuidString).path), "In-flight download cannot recreate completed trip cache")
    }
}
