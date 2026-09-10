//
//  MainTabView.swift
//  Picsel
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    let onLogout: () -> Void
    let onWithdraw: () -> Void

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            NavigationStack {
                HomeView(
                    onLogout: onLogout,
                    onWithdraw: onWithdraw
                )
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
        .tint(.primary)
    }
}

#Preview {
    MainTabView(
      onLogout: { },
      onWithdraw: { }
    )
    .environment(AppRouter())
    .modelContainer(for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self], inMemory: true)
}
