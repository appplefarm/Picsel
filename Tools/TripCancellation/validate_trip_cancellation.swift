import Foundation
import SwiftData

@main
struct CancellationChecks {
    struct Failed: Error { let message: String }
    static var checks = 0
    static let schema = Schema([Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self])

    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw Failed(message: message) }
        checks += 1
    }

    static func container(at url: URL? = nil, allowsSave: Bool = true) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, allowsSave: allowsSave, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func seed(_ context: ModelContext, title: String, done: Bool = false) -> Trip {
        let trip = Trip(title: title)
        trip.startTime = Date()
        trip.isDone = done
        trip.endTime = done ? Date() : nil
        trip.targetPixelCode = "47111"
        let stop = RouteStop(name: title, latitude: 36, longitude: 129, stopType: "destination", orderIndex: 0)
        let photo = TripPhoto(imageData: Data([1, 2, 3]), orderIndex: 0)
        trip.stops = [stop]
        trip.photos = [photo]
        context.insert(trip)
        return trip
    }

    static func main() throws {
        let suite = "PicselCancellationChecks." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try checkCancellation(defaults)
        defaults.removePersistentDomain(forName: suite)
        try checkGuards(defaults)
        defaults.removePersistentDomain(forName: suite)
        try checkDiskAndFailure(defaults)
        print("PASS: \(checks) trip cancellation checks (isolated SwiftData / no user data)")
    }

    static func checkCancellation(_ defaults: UserDefaults) throws {
        let store = try container()
        let context = ModelContext(store)
        context.autosaveEnabled = false
        let active = seed(context, title: "Cancel this trip")
        let history = seed(context, title: "Keep completed trip", done: true)
        let abandoned = seed(context, title: "Keep unrelated draft")
        let pixel = UserPixel(regionCode: 47111, regionName: "포항")
        pixel.totalVisits = 7
        pixel.trips = [history, active]
        context.insert(pixel)
        try context.save()
        let tripID = active.id, historyID = history.id, draftID = abandoned.id
        let stopID = active.stops[0].id, photoID = active.photos[0].id

        defaults.set(tripID.uuidString, forKey: "picsel.activeTripID")
        defaults.set(tripID.uuidString, forKey: "picsel.tripReadyTripID")
        let router = AppRouter(defaults: defaults)
        try router.restoreTrip(in: context)
        let stackBefore = router.homeStackID
        try check(router.sessionTrip?.id == tripID, "Trip remains active before confirmation")
        try check(try context.fetchCount(FetchDescriptor<Trip>()) == 3, "No mutation before confirmation")

        // A teammate's in-progress edit must neither be saved nor rolled back by cancellation.
        history.memo = "Unsaved edit"
        try router.cancelTrip(tripID, in: context)
        let verify = ModelContext(store)
        let remaining = try verify.fetch(FetchDescriptor<Trip>())
        try check(Set(remaining.map(\.id)) == Set([historyID, draftID]), "Only the active trip is deleted")
        try check(!verify.fetch(FetchDescriptor<RouteStop>()).contains { $0.id == stopID }, "Cancelled route stops cascade deleted")
        try check(!verify.fetch(FetchDescriptor<TripPhoto>()).contains { $0.id == photoID }, "Cancelled trip photos cascade deleted")
        try check(try verify.fetchCount(FetchDescriptor<RouteStop>()) == 2, "Other route stops preserved")
        try check(try verify.fetchCount(FetchDescriptor<TripPhoto>()) == 2, "Other photos preserved")
        let pixels = try verify.fetch(FetchDescriptor<UserPixel>())
        try check(pixels.count == 1 && pixels[0].totalVisits == 7, "Existing pixel and visit count unchanged")
        try check(pixels[0].trips.map(\.id) == [historyID], "Pixel relationship to cancelled trip cleared")
        try check(remaining.first { $0.id == historyID }?.isDone == true, "Completed history remains completed")
        try check(remaining.first { $0.id == draftID }?.isDone == false, "No completion flow runs for other drafts")
        try check(history.memo == "Unsaved edit", "Unrelated unsaved edit is not rolled back")
        try check(remaining.first { $0.id == historyID }?.memo == "", "Unrelated unsaved edit is not persisted")
        try check(router.sessionTrip == nil && router.activeTripID == nil, "Active session cleared")
        try check(router.tripReadyTripID == nil, "Legacy ready ID cleared")
        try check(router.homeStackID != stackBefore && router.selectedTab == .home, "Flow resets to home")
        try check(defaults.string(forKey: "picsel.activeTripID") == "", "No-restoration sentinel persists")
        try check(defaults.object(forKey: "picsel.tripReadyTripID") == nil, "Legacy restoration key removed")
        let relaunched = AppRouter(defaults: defaults)
        try relaunched.restoreTrip(in: ModelContext(store))
        try check(relaunched.sessionTrip == nil, "Relaunch does not restore cancelled trip or unrelated draft")

        do {
            try router.cancelTrip(tripID, in: context)
            throw Failed(message: "Duplicate cancellation should be rejected")
        } catch AppRouter.TripCancellationError.notActive {
            try check(try verify.fetchCount(FetchDescriptor<Trip>()) == 2, "Duplicate request does not delete anything else")
        }
    }

    static func checkGuards(_ defaults: UserDefaults) throws {
        let store = try container()
        let context = ModelContext(store)
        context.autosaveEnabled = false
        let active = seed(context, title: "Active")
        let other = seed(context, title: "Other")
        try context.save()
        let router = AppRouter(defaults: defaults)
        router.showTripReadyHome(for: active)
        let stack = router.homeStackID
        do {
            try router.cancelTrip(other.id, in: context)
            throw Failed(message: "Non-active trip must be rejected")
        } catch AppRouter.TripCancellationError.notActive {
            try check(router.activeTripID == active.id && router.homeStackID == stack, "Wrong trip ID leaves session unchanged")
        }
        active.isDone = true
        try context.save()
        do {
            try router.cancelTrip(active.id, in: context)
            throw Failed(message: "Completed trip must be rejected")
        } catch AppRouter.TripCancellationError.alreadyCompleted {
            try check(try context.fetchCount(FetchDescriptor<Trip>()) == 2, "Completed trip cannot be deleted through cancellation")
            try check(router.sessionTrip?.id == active.id, "Rejected cancellation preserves flow")
        }
    }

    static func checkDiskAndFailure(_ defaults: UserDefaults) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PicselCancellationChecks-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("test.store")
        var tripID = UUID()
        do {
            let store = try container(at: url)
            let context = ModelContext(store)
            context.autosaveEnabled = false
            let active = seed(context, title: "Persisted trip")
            tripID = active.id
            try context.save()
        }
        defaults.set(tripID.uuidString, forKey: "picsel.activeTripID")
        do {
            let readOnly = try container(at: url, allowsSave: false)
            let context = ModelContext(readOnly)
            let router = AppRouter(defaults: defaults)
            try router.restoreTrip(in: context)
            let stack = router.homeStackID
            var failed = false
            do { try router.cancelTrip(tripID, in: context) }
            catch { failed = true }
            try check(failed, "Read-only store causes deletion failure")
            try check(router.activeTripID == tripID && router.sessionTrip?.id == tripID, "Save failure preserves active trip")
            try check(router.homeStackID == stack, "Save failure does not navigate home")
            try check(defaults.string(forKey: "picsel.activeTripID") == tripID.uuidString, "Save failure preserves restoration ID")
        }
        do {
            let store = try container(at: url)
            let context = ModelContext(store)
            let router = AppRouter(defaults: defaults)
            try router.restoreTrip(in: context)
            try check(router.sessionTrip?.id == tripID, "Trip is restorable after failed cancellation")
            try router.cancelTrip(tripID, in: context)
        }
        do {
            let reopened = try container(at: url)
            let context = ModelContext(reopened)
            let router = AppRouter(defaults: defaults)
            try router.restoreTrip(in: context)
            try check(router.sessionTrip == nil, "Reopened disk store does not restore cancelled trip")
            try check(try context.fetchCount(FetchDescriptor<Trip>()) == 0, "Trip deletion persists on disk")
            try check(try context.fetchCount(FetchDescriptor<RouteStop>()) == 0, "Route deletion persists on disk")
            try check(try context.fetchCount(FetchDescriptor<TripPhoto>()) == 0, "Photo deletion persists on disk")
        }
    }
}
