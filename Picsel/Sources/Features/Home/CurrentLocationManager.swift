import CoreLocation
import Observation

@Observable
final class CurrentLocationManager: NSObject {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private(set) var currentLocation: CLLocation?
    private(set) var localityName = "현재 위치 확인 중"
    private(set) var errorMessage: String?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    var isLocationAuthorized: Bool {
        authorizationStatus == .authorizedAlways
            || authorizationStatus == .authorizedWhenInUse
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestCurrentLocation() {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            currentLocation = nil
            localityName = "위치 권한이 필요해요"
            errorMessage = "설정에서 위치 권한을 허용해 주세요."
        @unknown default:
            errorMessage = "위치 권한 상태를 확인할 수 없습니다."
        }
    }

    private func updateLocality(for location: CLLocation) {
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(
            location,
            preferredLocale: Locale(identifier: "ko_KR")
        ) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.localityName = "현재 위치"
                    return
                }
                guard let placemark = placemarks?.first else {
                    self.localityName = "현재 위치"
                    return
                }

                let city = placemark.locality ?? placemark.subAdministrativeArea
                let district = placemark.subLocality
                let components = [city, district]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                self.localityName = components.isEmpty
                    ? "현재 위치"
                    : components.joined(separator: " ")
            }
        }
    }
}

extension CurrentLocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            currentLocation = nil
            localityName = "위치 권한이 필요해요"
            errorMessage = "설정에서 위치 권한을 허용해 주세요."
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        updateLocality(for: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
        localityName = "현재 위치를 찾을 수 없어요"
    }
}
