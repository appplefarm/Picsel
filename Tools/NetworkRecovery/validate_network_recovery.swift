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
