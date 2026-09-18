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
/// 반면 주소나 장소명은 사람이 찾아가는 곳을 가리키므로, 주소나 장소명으로 검색하면
/// 자연스럽게 도로 가까운 지점이 나옵니다.
protocol RouteCoordinateCorrecting: Sendable {
    /// 보정된 좌표와 성공한 단계 정보입니다. 도로가 없어 보정할 수 없으면 nil입니다.
    func correctedCoordinate(
        forName name: String,
        address: String?,
        near coordinate: CLLocationCoordinate2D
    ) async -> RouteCoordinateCorrection?
}

/// 보정된 좌표와 보정에 성공한 단계 정보입니다.
struct RouteCoordinateCorrection: Sendable, Equatable {
    let coordinate: CLLocationCoordinate2D
    let stepDescription: String

    static func == (lhs: RouteCoordinateCorrection, rhs: RouteCoordinateCorrection) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.stepDescription == rhs.stepDescription
    }
}

/// 네이버 클라우드 플랫폼(NCP) 지오코딩 및 지역검색으로 좌표를 보정합니다.
///
/// 1단계: 장소 주소 지오코딩
/// 2단계: 원래 좌표 역지오코딩 → 도로명주소 지오코딩
/// 3단계: 장소명 네이버 지역검색 → roadAddress 지오코딩 (3km 거리 상한 검증)
struct NaverCoordinateCorrector: RouteCoordinateCorrecting {

    private let session: URLSession
    private let geocodeURL = URL(string: "https://maps.apigw.ntruss.com/map-geocode/v2/geocode")!
    private let reverseGeocodeURL =
        URL(string: "https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc")!
    private let searchLocalURL =
        URL(string: "https://naverapihub.apigw.ntruss.com/search/v1/local")!

    /// 지역검색으로 찾은 위치가 원래 장소와 너무 멀면 다른 동네의 동명 장소로 보고 버립니다.
    private let maxLocalSearchDistanceMeters: CLLocationDistance = 3_000

    init(session: URLSession = .shared) {
        self.session = session
    }

    func correctedCoordinate(
        forName name: String,
        address: String?,
        near coordinate: CLLocationCoordinate2D
    ) async -> RouteCoordinateCorrection? {
        // 1단계: 이미 주소를 들고 있으면 주소로 지오코딩합니다.
        if let address, !address.isEmpty, let found = await geocode(address) {
            return RouteCoordinateCorrection(coordinate: found, stepDescription: "1단계 주소")
        }

        // 2단계: 주소가 없거나 실패하면 좌표에서 도로명주소를 역지오코딩으로 얻어 다시 찾습니다.
        if let roadAddress = await roadAddress(near: coordinate),
           let found = await geocode(roadAddress) {
            return RouteCoordinateCorrection(coordinate: found, stepDescription: "2단계 역지오코딩")
        }

        // 3단계: 주소 자체가 산번지인 경우 장소명으로 지역검색을 하여 대표 지점의 도로명주소를 찾습니다.
        if let found = await localSearchCoordinate(forName: name, near: coordinate) {
            return RouteCoordinateCorrection(coordinate: found, stepDescription: "3단계 지역검색")
        }

        return nil
    }

    // MARK: - 1·2단계: 주소 → 좌표

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
            let data = await sendMapAPI(url),
            let response = try? JSONDecoder().decode(NaverGeocodeResponseDTO.self, from: data),
            let match = response.addresses.first(where: { !($0.roadAddress ?? "").isEmpty }),
            let coordinate = match.coordinate
        else { return nil }

        return coordinate
    }

    // MARK: - 2단계: 좌표 → 도로명주소

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
            let data = await sendMapAPI(url),
            let response = try? JSONDecoder().decode(NaverReverseGeocodeResponseDTO.self, from: data)
        else { return nil }

        return response.results.first(where: { $0.name == "roadaddr" })?.roadAddressText
    }

    // MARK: - 3단계: 장소명 → 지역검색 → 도로명주소 → 좌표

    private func localSearchCoordinate(
        forName name: String,
        near coordinate: CLLocationCoordinate2D
    ) async -> CLLocationCoordinate2D? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        guard var components = URLComponents(url: searchLocalURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "query", value: trimmedName),
            URLQueryItem(name: "display", value: "5"),
            URLQueryItem(name: "start", value: "1"),
            URLQueryItem(name: "sort", value: "random")
        ]

        guard
            let url = components.url,
            let data = await sendSearchAPI(url),
            let response = try? JSONDecoder().decode(NaverLocalSearchResponseDTO.self, from: data)
        else { return nil }

        let originalLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        // 검색 결과 중 roadAddress가 있고 원래 위치에서 3km 이내인 첫 번째 유효 좌표를 찾습니다.
        for item in response.items {
            guard let roadAddress = item.roadAddress, !roadAddress.isEmpty else { continue }
            guard let foundCoordinate = await geocode(roadAddress) else { continue }

            let candidateLocation = CLLocation(
                latitude: foundCoordinate.latitude,
                longitude: foundCoordinate.longitude
            )
            let distance = originalLocation.distance(from: candidateLocation)

            // 엉뚱한 동네의 동명 장소를 잡지 않도록 거리 상한을 검증합니다.
            if distance <= maxLocalSearchDistanceMeters {
                return foundCoordinate
            }
        }

        return nil
    }

    // MARK: - 통신 공통

    private func sendMapAPI(_ url: URL) async -> Data? {
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

        guard
            let (data, response) = try? await session.data(for: request),
            let status = (response as? HTTPURLResponse)?.statusCode,
            (200..<300).contains(status)
        else { return nil }

        return data
    }

    private func sendSearchAPI(_ url: URL) async -> Data? {
        guard
            let clientID = Bundle.main.object(forInfoDictionaryKey: "NAVER_SEARCH_CLIENT_ID") as? String,
            let clientSecret = Bundle.main
                .object(forInfoDictionaryKey: "NAVER_SEARCH_CLIENT_SECRET") as? String,
            !clientID.isEmpty, !clientSecret.isEmpty,
            !clientID.contains("$("), !clientSecret.contains("$(")
        else { return nil }

        var request = URLRequest(url: url)
        request.setValue(clientID, forHTTPHeaderField: "x-ncp-apigw-api-key-id")
        request.setValue(clientSecret, forHTTPHeaderField: "x-ncp-apigw-api-key")

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

private struct NaverLocalSearchResponseDTO: Decodable {
    struct Item: Decodable {
        let title: String?
        let link: String?
        let category: String?
        let description: String?
        let telephone: String?
        let address: String?
        let roadAddress: String?
        let mapx: String?
        let mapy: String?
    }

    let items: [Item]
}

