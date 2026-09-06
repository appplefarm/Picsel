//
//  NavigationApp.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import Foundation
import UIKit

/// 길찾기를 넘길 목적지입니다.
struct NavigationDestination {
    let name: String
    let latitude: Double
    let longitude: Double
}

/// 사용자가 고를 수 있는 내비게이션 앱입니다.
///
/// 출발지는 넘기지 않습니다. 세 앱 모두 목적지만 주면 현재 위치에서 출발하고,
/// 출발지를 명시하면 오히려 앱이 잡은 최신 위치를 무시하게 됩니다.
///
/// TODO: 카카오내비는 Kakao iOS SDK와 네이티브 앱 키가 필요해 별도 이슈로 추가합니다.
enum NavigationApp: String, CaseIterable, Identifiable, Codable {
    case kakaoMap
    case naverMap
    case tmap

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kakaoMap: "카카오맵"
        case .naverMap: "네이버지도"
        case .tmap: "티맵"
        }
    }

    /// 설치 여부를 확인할 때 쓰는 스킴입니다.
    /// Info.plist의 LSApplicationQueriesSchemes에 같은 값이 등록되어 있어야 합니다.
    var scheme: String {
        switch self {
        case .kakaoMap: "kakaomap"
        case .naverMap: "nmap"
        case .tmap: "tmap"
        }
    }

    /// 앱이 없을 때 보낼 App Store 주소입니다.
    var appStoreURL: URL? {
        switch self {
        case .kakaoMap: URL(string: "https://apps.apple.com/app/id304608425")
        case .naverMap: URL(string: "https://apps.apple.com/app/id311867728")
        case .tmap: URL(string: "https://apps.apple.com/app/id431589174")
        }
    }

    /// 앱마다 좌표 파라미터의 이름과 순서가 다릅니다.
    /// 특히 티맵은 goalx가 경도, goaly가 위도라 헷갈리기 쉬워 여기서만 다룹니다.
    func routeURL(to destination: NavigationDestination) -> URL? {
        let name = destination.name
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        switch self {
        case .kakaoMap:
            return URL(string: "kakaomap://route?ep=\(destination.latitude),\(destination.longitude)&by=CAR")

        case .naverMap:
            // 네이버지도는 호출한 앱을 식별하기 위해 번들 ID를 요구합니다.
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            return URL(
                string: "nmap://route/car?dlat=\(destination.latitude)&dlng=\(destination.longitude)"
                    + "&dname=\(name)&appname=\(bundleID)"
            )

        case .tmap:
            return URL(
                string: "tmap://route?goalname=\(name)"
                    + "&goalx=\(destination.longitude)&goaly=\(destination.latitude)"
            )
        }
    }
}

/// 선택한 내비 앱으로 길안내를 넘깁니다.
@MainActor
enum NavigationAppLauncher {

    /// 기기에 앱이 깔려 있는지 확인합니다.
    /// LSApplicationQueriesSchemes에 스킴이 없으면 설치돼 있어도 false가 나옵니다.
    static func isInstalled(_ app: NavigationApp) -> Bool {
        guard let url = URL(string: "\(app.scheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// 앱이 있으면 길안내를, 없으면 App Store를 엽니다.
    static func open(_ app: NavigationApp, to destination: NavigationDestination) {
        if isInstalled(app), let routeURL = app.routeURL(to: destination) {
            UIApplication.shared.open(routeURL)
            return
        }

        if let appStoreURL = app.appStoreURL {
            UIApplication.shared.open(appStoreURL)
        }
    }
}
