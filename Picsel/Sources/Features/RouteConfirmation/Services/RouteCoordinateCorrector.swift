//
//  RouteCoordinateCorrector.swift
//  Picsel
//
//  Created by kosoobin on 9/18/26.
//

import CoreLocation
import Foundation

/// 자동차로 갈 수 없는 지점을 갈 수 있는 지점으로 옮겨 줍니다.
///
/// 관광 API가 주는 좌표는 "사진을 찍은 자리"라 산 중턱이나 공원 한가운데일 수 있습니다.
/// 반면 주소는 사람이 찾아가는 곳을 가리키므로, 주소를 다시 좌표로 바꾸면
/// 자연스럽게 도로 가까운 지점이 나옵니다.
protocol RouteCoordinateCorrecting: Sendable {
    /// 보정된 좌표입니다. 도로가 없어 보정할 수 없으면 nil입니다.
    func correctedCoordinate(
        forAddress address: String?,
        near coordinate: CLLocationCoordinate2D
    ) async -> CLLocationCoordinate2D?
}

/// 네이버 클라우드 지오코딩으로 좌표를 보정합니다.
///
/// 지도 SDK 때문에 이미 쓰고 있는 계정을 그대로 씁니다.
/// 월 300만 건까지 무료라, 경로가 실패했을 때만 부르는 이 용도에는 넉넉합니다.
struct NaverCoordinateCorrector: RouteCoordinateCorrecting {

    private let session: URLSession
    private let geocodeURL = URL(string: "https://maps.apigw.ntruss.com/map-geocode/v2/geocode")!
    private let reverseGeocodeURL =
        URL(string: "https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func correctedCoordinate(
        forAddress address: String?,
        near coordinate: CLLocationCoordinate2D
    ) async -> CLLocationCoordinate2D? {
        // 이미 주소를 들고 있으면 한 번만 물어보면 됩니다.
        if let address, !address.isEmpty, let found = await geocode(address) {
            return found
        }

        // 주소가 없거나 그 주소로 못 찾은 경우입니다. 좌표에서 도로명주소를 얻어 다시 찾습니다.
        guard let roadAddress = await roadAddress(near: coordinate) else { return nil }
        return await geocode(roadAddress)
    }

    // MARK: - 주소 → 좌표

    /// 도로명주소를 가진 결과만 받아들입니다.
    ///
    /// 도로명주소가 비어 있다는 것은 접근할 도로가 없다는 뜻입니다.
    /// (예: "부산광역시 사상구 엄궁동 산19"는 지번만 있고 도로명이 없습니다.)
    /// 그런 곳의 좌표를 그대로 쓰면 보정해 봐야 또 거절당합니다.
    private func geocode(_ address: String) async -> CLLocationCoordinate2D? {
        guard var components = URLComponents(url: geocodeURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "query", value: address)]

        guard
            let url = components.url,
            let data = await send(url),
            let response = try? JSONDecoder().decode(NaverGeocodeResponseDTO.self, from: data),
            let match = response.addresses.first(where: { !($0.roadAddress ?? "").isEmpty }),
            let coordinate = match.coordinate
        else { return nil }

        return coordinate
    }

    // MARK: - 좌표 → 도로명주소

    private func roadAddress(near coordinate: CLLocationCoordinate2D) async -> String? {
        guard
            var components = URLComponents(url: reverseGeocodeURL, resolvingAgainstBaseURL: false)
        else { return nil }

        components.queryItems = [
            // 네이버도 "경도,위도" 순서입니다.
            URLQueryItem(name: "coords", value: "\(coordinate.longitude),\(coordinate.latitude)"),
            URLQueryItem(name: "orders", value: "roadaddr"),
            URLQueryItem(name: "output", value: "json")
        ]

        guard
            let url = components.url,
            let data = await send(url),
            let response = try? JSONDecoder().decode(NaverReverseGeocodeResponseDTO.self, from: data)
        else { return nil }

        return response.results.first(where: { $0.name == "roadaddr" })?.roadAddressText
    }

    // MARK: - 공통

    private func send(_ url: URL) async -> Data? {
        guard
            let clientID = Bundle.main.object(forInfoDictionaryKey: "NAVER_MAPS_CLIENT_ID") as? String,
            let clientSecret = Bundle.main
                .object(forInfoDictionaryKey: "NAVER_MAPS_CLIENT_SECRET") as? String,
            !clientID.isEmpty, !clientSecret.isEmpty,
            !clientID.contains("$("), !clientSecret.contains("$(")
        else { return nil }

        var request = URLRequest(url: url)
        request.setValue(clientID, forHTTPHeaderField: "x-ncp-apigw-api-key-id")
        request.setValue(clientSecret, forHTTPHeaderField: "x-ncp-apigw-api-key")

        // 보정은 있으면 좋은 정도의 기능입니다. 실패해도 경로 자체는 계속 만들어야 하므로
        // 오류를 던지지 않고 "보정하지 못했다"로만 처리합니다.
        guard
            let (data, response) = try? await session.data(for: request),
            let status = (response as? HTTPURLResponse)?.statusCode,
            (200..<300).contains(status)
        else { return nil }

        return data
    }
}

// MARK: - 응답 DTO

private struct NaverGeocodeResponseDTO: Decodable {
    struct Address: Decodable {
        let roadAddress: String?
        /// 네이버는 좌표를 문자열로 내려 줍니다.
        let x: String?
        let y: String?

        var coordinate: CLLocationCoordinate2D? {
            guard let x, let y, let longitude = Double(x), let latitude = Double(y) else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    let addresses: [Address]
}

private struct NaverReverseGeocodeResponseDTO: Decodable {
    struct Result: Decodable {
        struct Region: Decodable {
            struct Area: Decodable { let name: String? }
            let area1: Area?
            let area2: Area?
        }

        struct Land: Decodable {
            let name: String?
            let number1: String?
            let number2: String?

            /// "낙동남로 1240" 같은 도로명 + 건물번호입니다.
            var text: String? {
                guard let name, !name.isEmpty, let number1, !number1.isEmpty else { return nil }
                guard let number2, !number2.isEmpty else { return "\(name) \(number1)" }
                return "\(name) \(number1)-\(number2)"
            }
        }

        let name: String?
        let region: Region?
        let land: Land?

        /// 시·도와 시·군·구까지 붙여야 같은 도로명이 여러 지역에 있어도 헷갈리지 않습니다.
        var roadAddressText: String? {
            guard let road = land?.text else { return nil }
            let area = [region?.area1?.name, region?.area2?.name].compactMap { $0 }
            return (area + [road]).joined(separator: " ")
        }
    }

    let results: [Result]
}
