//
//  PicselApp.swift
//  Picsel
//
//  Created by 김나영 on 8/13/26.
//

import SwiftUI
import SwiftData

@main
struct PicselApp: App {
    var body: some Scene {
        WindowGroup {
            PhotoExploreRootView()
        }
        // 2. SwiftData 모델들을 앱 전체에서 쓸 수 있도록 컨테이너 등록
        .modelContainer(for: [
            Trip.self,
            RouteStop.self,
            TripPhoto.self,
            UserPixel.self
        ])
    }}
