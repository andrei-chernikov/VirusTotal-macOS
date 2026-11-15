//
//  WelcomeView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-24.
//

import SwiftUI

/// Given a systemImage and a title, create a welcome view in VStack
struct WelcomeView: View {
    let title: LocalizedStringKey
    let systemImage: String
    @Environment(\.inMenuPanel) private var inMenuPanel

    var body: some View {
        VStack(alignment: .center) {
            Image(systemName: systemImage)
                .font(.system(size: inMenuPanel ? 44 : 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.title3.bold())
                .padding(.top, inMenuPanel ? 6 : 16)
        }
    }
}

#Preview {
    WelcomeView(title: "urlview.welcome.title",
                systemImage: "network.badge.shield.half.filled")
        .frame(minWidth: 600, minHeight: 500)
}
