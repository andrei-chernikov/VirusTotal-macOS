//
//  FileTypeView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-03.
//

import SwiftUI

struct FileTypeView: View {
    private var viewModel = FileViewModel.shared

    @Environment(\.inMenuPanel) private var inMenuPanel

    var body: some View {
        let layout = inMenuPanel ? AnyLayout(HStackLayout(spacing: 6)) : AnyLayout(VStackLayout())
        let iconSize: CGFloat = inMenuPanel ? 22 : 50
        layout {
            if let image = viewModel.thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: "doc.questionmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            }
            Text(String(viewModel.fileName?.split(separator: ".").last ?? "n/a"))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    FileTypeView()
        .frame(width: 180, height: 180)
}
