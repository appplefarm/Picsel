//
//  RouteConfirmationViewModel.swift
//  Picsel
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class RouteConfirmationViewModel {
    private let trip: Trip
    private let thumbnailURLsByStopID: [UUID: URL]
    private let travelMinutesByStopID: [UUID: Int]
    private let estimatedDurationMinutes: Int?

    private(set) var routeStops: [RouteStop]

    init(
        trip: Trip,
        estimatedDurationMinutes: Int? = nil,
        thumbnailURLsByStopID: [UUID: URL] = [:],
        travelMinutesByStopID: [UUID: Int] = [:]
    ) {
        self.trip = trip
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.thumbnailURLsByStopID = thumbnailURLsByStopID
        self.travelMinutesByStopID = travelMinutesByStopID
        routeStops = trip.stops
    }

    var activeTrip: Trip { trip }

    var routeSummary: String {
        var values: [String] = []

        if let distanceText {
            values.append(distanceText)
        }

        if let durationText {
            values.append(durationText)
        }

        guard !values.isEmpty else {
            return "경로 정보를 계산하고 있어요"
        }

        values.append("자동차 기준")
        return values.joined(separator: " · ")
    }

    func beginEditing() {
        routeStops = trip.stops
    }

    func commitEditing() {
        let remainingStopIDs = Set(routeStops.map(\.id))

        for stop in trip.stops where !remainingStopIDs.contains(stop.id) {
            stop.trip = nil
        }

        for stop in routeStops {
            stop.trip = trip
        }

        trip.stops = routeStops
    }

    func removeStops(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where routeStops.indices.contains(index) {
            routeStops.remove(at: index)
        }
    }

    func moveStops(from offsets: IndexSet, to destination: Int) {
        routeStops.move(fromOffsets: offsets, toOffset: destination)
    }

    func thumbnailURL(for stop: RouteStop) -> URL? {
        thumbnailURLsByStopID[stop.id]
    }

    func travelMinutes(for stop: RouteStop) -> Int? {
        travelMinutesByStopID[stop.id]
    }

    private var distanceText: String? {
        guard let totalDistanceMeters = trip.totalDistanceMeters else { return nil }

        let kilometers = totalDistanceMeters / 1_000
        let formattedDistance = kilometers.formatted(
            .number.precision(.fractionLength(kilometers < 10 ? 0...1 : 0...0))
        )
        return "총 \(formattedDistance)km"
    }

    private var durationText: String? {
        guard let estimatedDurationMinutes else { return nil }

        let hours = estimatedDurationMinutes / 60
        let minutes = estimatedDurationMinutes % 60

        switch (hours, minutes) {
        case (0, let minutes):
            return "약 \(minutes)분"
        case (let hours, 0):
            return "약 \(hours)시간"
        default:
            return "약 \(hours)시간 \(minutes)분"
        }
    }
}
