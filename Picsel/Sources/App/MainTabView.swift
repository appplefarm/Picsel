//
//  MainTabView.swift
//  Picsel
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    let onLogout: () -> Void

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(onLogout: onLogout)
            }
            .tabItem {
                Label("지도", systemImage: "house.fill")
            }

            NavigationStack {
                PicselMapScreen()
            }
            .tabItem {
                Label("픽셀맵", systemImage: "mappin.and.ellipse")
            }
        }
        .tint(.primary)
    }
}

#Preview {
    MainTabView(onLogout: { })
        .modelContainer(for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self], inMemory: true)
}
