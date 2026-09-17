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
    private let modelContainer: ModelContainer

    init() {
#if DEBUG
        print("[Picsel] Debug 실행 중")
#else
        print("[Picsel] Release 실행 중")
#endif
        let schema = Schema([
            Trip.self,
            RouteStop.self,
            TripPhoto.self,
            UserPixel.self
        ])
        // 사용자 여행은 기존 기기 저장소에만 보관합니다.
        // 사진 좌표 조회용 CloudKit capability가 있어도 private DB로 자동 동기화하지 않습니다.
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // 저장소 오류를 메모리 저장으로 우회하면 종료 후 여행이 사라집니다.
            fatalError("여행 저장소를 열지 못했습니다: \(error)")
        }
    }
        
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
    }
}
