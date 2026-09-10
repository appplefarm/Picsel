//
//  MainTabView.swift
//  Picsel
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
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
    MainTabView()
        .modelContainer(for: [Trip.self, RouteStop.self, TripPhoto.self, UserPixel.self], inMemory: true)
}
