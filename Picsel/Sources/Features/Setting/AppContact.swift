//
//  AppContact.swift
//  Picsel
//

import UIKit

enum AppContact {
    static let supportEmail = "ehdtjs3658@naver.com"
    static let privacyPolicyURL = URL(string: "https://appplefarm.github.io/picsel-policy/privacy/")
    static let supportURL = URL(string: "https://appplefarm.github.io/picsel-policy/support/")
    static let mailSubject = "[Picsel 문의]"
    static var supportMailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: mailSubject),
            URLQueryItem(name: "body", value: supportMailBody)
        ]
        return components.url
    }

    private static var supportMailBody: String {
        """


        ---
        앱 버전: \(AppInfo.displayVersion)
        iOS 버전: \(UIDevice.current.systemVersion)
        기기 정보: \(UIDevice.current.model)
        """
    }
}

enum AppInfo {
    static var displayVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?) where !build.isEmpty:
            return "\(version) (\(build))"
        case let (version?, _):
            return version
        default:
            return "-"
        }
    }
}
