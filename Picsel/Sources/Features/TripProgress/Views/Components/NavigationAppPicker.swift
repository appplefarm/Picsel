//
//  NavigationAppPicker.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import SwiftUI

/// 길찾기에 사용할 내비 앱을 고르는 토글입니다.
///
/// 원래는 온보딩에서 한 번 받을 값이라, 여기서 고른 값도 같은 저장소를 씁니다.
/// 온보딩이 붙으면 이 토글만 걷어내면 됩니다.
struct NavigationAppPicker: View {

    @Binding var selection: NavigationApp

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("길찾기에 사용할 앱", selection: $selection) {
                ForEach(NavigationApp.allCases) { app in
                    Text(app.displayName).tag(app)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

#if DEBUG
private struct NavigationAppPickerPreview: View {
    @State private var selection: NavigationApp = .naverMap

    var body: some View {
        NavigationAppPicker(selection: $selection)
            .padding()
    }
}

#Preview("내비 앱 선택") {
    NavigationAppPickerPreview()
}
#endif
