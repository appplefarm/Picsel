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
        GMSServices.provideAPIKey("")
    }
    
    var body: some Scene {
        WindowGroup {
            // 1. 테스트를 위한 임시(더미) Trip 객체 생성
            let dummyTrip = Trip(title: "포항 테스트 여행")
            let viewModel = TransitSwipeViewModel(trip: dummyTrip)
            
            TransitSwipeView(viewModel: viewModel)
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
