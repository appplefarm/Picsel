//
//  PicselApp.swift
//  Picsel
//
//  Created by 김나영 on 8/13/26.
//

import SwiftUI
import SwiftData
import GoogleMaps

@main
struct PicselApp: App {
    init() {
        guard let apiKey = Bundle.main.object(
            forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY"
        ) as? String,
        !apiKey.isEmpty,
        !apiKey.contains("$(")
        else {
            fatalError("GoogleMapsAPIKey를 불러오지 못했습니다.")
        }
        GMSServices.provideAPIKey(apiKey)
    }
        
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        // 2. SwiftData 모델들을 앱 전체에서 쓸 수 있도록 컨테이너 등록
        .modelContainer(for: [
            Trip.self,
            RouteStop.self,
            TripPhoto.self,
            UserPixel.self
        ])
    }
}
