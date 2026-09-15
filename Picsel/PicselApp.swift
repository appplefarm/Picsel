//
//  PicselApp.swift
//  Picsel
//
//  Created by 김나영 on 8/13/26.
//

import SwiftUI
import SwiftData
import GoogleMaps
import CloudKit

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
                // TODO: iCloud 준비 확인용 임시 호출. 2단계 끝나면 지웁니다.
                #if DEBUG
                .task { await CloudKitSmokeTest.run() }
                #endif
        }
        // 2. SwiftData 모델들을 앱 전체에서 쓸 수 있도록 컨테이너 등록
        .modelContainer(for: [
            Trip.self,
            RouteStop.self,
            TripPhoto.self,
            UserPixel.self
        ])
//        WindowGroup {
//            // 1. 테스트를 위한 임시(더미) Trip 객체 생성
//            let dummyTrip = Trip(title: "포항 테스트 여행")
//            let viewModel = TransitSwipeViewModel(trip: dummyTrip)
//            
//            TransitSwipeView(viewModel: viewModel)
//        }
//        // 2. SwiftData 모델들을 앱 전체에서 쓸 수 있도록 컨테이너 등록
//        .modelContainer(for: [
//            Trip.self,
//            RouteStop.self,
//            TripPhoto.self,
//            UserPixel.self
//        ])
    }
}
