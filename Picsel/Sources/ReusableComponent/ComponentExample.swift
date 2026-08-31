//
//  ComponentExample.swift
//  Picsel
//
//  Created by 김나영 on 8/13/26.
//

import SwiftUI

struct ComponentExample: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ComponentExample()
}
