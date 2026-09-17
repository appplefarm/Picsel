//
//  MainTabView.swift
//  Picsel
//

import SwiftData
import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    init() {
        UITabBar.appearance().unselectedItemTintColor = UIColor(Constants.labelsVibrantTertiary)
    }

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            NavigationStack {
                HomeRootView()
            }
            // 여행 흐름을 마치면 이 값이 바뀌면서 스택이 첫 화면으로 되돌아갑니다.
            .id(router.homeStackID)
            .tabItem {
                Label("지도", systemImage: "house.fill")
            }
            .tag(AppRouter.Tab.home)

            NavigationStack {
                PicselMapScreen()
            }
            .tabItem {
                Label("픽셀맵", systemImage: "mappin.and.ellipse")
            }
            .tag(AppRouter.Tab.picselMap)
        }
        .tint(Constants.selectedTabColor)
    }
}

private enum Constants {
    static let selectedTabColor = Color(red: 0.17, green: 0.55, blue: 0.45)
    static let labelsVibrantTertiary = Color(
        red: 191 / 255,
        green: 191 / 255,
        blue: 191 / 255
    )
}

#Preview {
    MainTabView()
    .environment(AppRouter())
    .modelContainer(for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self], inMemory: true)
}
