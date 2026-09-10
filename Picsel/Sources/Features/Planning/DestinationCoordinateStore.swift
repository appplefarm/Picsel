//
//  DestinationCoordinateStore.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import Foundation

/// 관광공모전 수상작 API는 위경도를 내려주지 않아, 좌표를 수기로 채워 넣는 중입니다.
///
/// 좌표 수집이 자동화되면 이 파일은 삭제하고 API 응답값을 그대로 사용합니다.
/// 그때까지는 경로 화면이 항상 유효한 목적지를 갖도록 여기서 좌표를 보강합니다.
enum DestinationCoordinateStore {
    struct Entry {
        let name: String
        let address: String
        let latitude: Double
        let longitude: Double
    }

    /// 수상작 contentId → 좌표
    private static let entriesByContentID: [String: Entry] = [
        "8mmyYP": ancharPointOfIgari
    ]

    /// 2025 수상작 · 이가리 닻 전망대 (경북 포항시 북구 청하면)
    static let ancharPointOfIgari = Entry(
        name: "이가리 닻 전망대",
//        address: "경상북도 포항시 북구 청하면 이가리",
        address: "경상북도 포항시 북구 청하면 이가리",
        latitude: 36.187_992_080_205_4,
        longitude: 129.379_004_542_389
    )

    /// 좌표가 확인된 목적지만 반환합니다.
    ///
    /// 알 수 없는 장소를 임의의 좌표로 대체하면 잘못된 경로를 만들 수 있으므로,
    /// 좌표가 없을 때는 호출자가 선택을 막거나 오류 상태를 표시합니다.
    static func entry(forContentID contentID: String) -> Entry? {
        entriesByContentID[contentID]
    }
}
