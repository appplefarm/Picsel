//
//  DestinationDetailViewModel.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/15/26.
//

import CoreLocation
import Observation

/// 사진 상세를 열었을 때만 기존 길찾기 서비스로 자동차 거리·시간을 조회합니다.
@MainActor
@Observable
final class DestinationDetailViewModel {
    enum TravelState {
        case loading
        case loaded(DestinationDetailInfo)
        case unavailable(String)
        case failed(RequestFailure)
    }

    private let destination: PhotoDestination
    private let directionsService: any RouteDirectionsProviding
    @ObservationIgnored private var activeRequestID: UUID?

    private(set) var travelState: TravelState = .loading
    private(set) var retryAttempt = 0

    init(destination: PhotoDestination, directionsService: any RouteDirectionsProviding) {
        self.destination = destination
        self.directionsService = directionsService
    }

    func retry() {
        retryAttempt += 1
    }

    func retryAfterReconnection() {
        guard case .failed(let failure) = travelState, failure.retriesOnReconnect else { return }
        retry()
    }

    func loadTravelInfo(from origin: CLLocation?) async {
        let requestID = UUID()
        activeRequestID = requestID

        guard destination.canSelectAsDestination,
              let latitude = destination.latitude,
              let longitude = destination.longitude else {
            travelState = .unavailable("목적지 위치 정보가 없어 거리·시간을 표시할 수 없어요.")
            return
        }

        // 홈 지도의 기본 좌표를 사용자의 현재 위치로 오인하지 않도록 실제 위치만 받습니다.
        guard let origin, origin.horizontalAccuracy >= 0,
              CLLocationCoordinate2DIsValid(origin.coordinate) else {
            travelState = .unavailable("현재 위치를 확인할 수 없어 거리·시간을 표시할 수 없어요.")
            return
        }

        travelState = .loading

        do {
            try Task.checkCancellation()
            let directions = try await directionsService.directions(
                origin: origin.coordinate,
                waypoints: [],
                destination: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            )
            try Task.checkCancellation()
            // 위치가 바뀌어 새 요청이 시작됐다면 늦게 도착한 이전 결과는 버립니다.
            guard activeRequestID == requestID else { return }

            let minutes = (directions.duration / 60).rounded(.up)
            guard directions.distanceMeters >= 0,
                  directions.duration >= 0,
                  minutes.isFinite, minutes >= 0, minutes < Double(Int.max) else {
                travelState = .failed(.invalidResponse)
                return
            }

            travelState = .loaded(DestinationDetailInfo(
                destination: destination,
                distanceKilometers: Double(directions.distanceMeters) / 1_000,
                estimatedDurationMinutes: Int(minutes)
            ))
        } catch {
            // URLSession 취소가 서비스 오류로 감싸져 전달되는 경우도 오류 UI를 띄우지 않습니다.
            let underlying: Error
            if case .networkFailure(let cause) = error as? RouteDirectionsError {
                underlying = cause
            } else { underlying = error }
            guard !Task.isCancelled, !RequestFailure.isCancellation(underlying),
                  activeRequestID == requestID else { return }
            travelState = .failed((error as? RouteDirectionsError)?.requestFailure ?? RequestFailure(error))
        }
    }
}
