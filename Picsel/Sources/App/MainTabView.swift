//
//  MainTabView.swift
//  Picsel
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("홈", systemImage: "house.fill")
            }

            NavigationStack {
                PicxelMapView()
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
}
