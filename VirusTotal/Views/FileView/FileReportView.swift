//
//  FileReportView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-02.
//

import SwiftUI

struct FileReportView: View {
    private var viewModel = FileViewModel.shared

    @Environment(\.inMenuPanel) private var inMenuPanel

    var body: some View {
        if inMenuPanel {
            ViewThatFits(in: .vertical) {
                compactReport.fixedSize(horizontal: false, vertical: true)
                ScrollView {
                    compactReport
                }
            }
        } else {
            Form {
                HStack(alignment: .center) {
                    Spacer()
                    FileTypeView().padding(.trailing, 8)
                    Spacer()
                    FileChartView()
                        .frame(width: 210, height: 150)
                        .padding(.vertical, 10)
                        .padding(.trailing, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                details
            }
            .formStyle(.grouped)
            .scrollIndicators(.hidden)
        }
    }

    private var compactReport: some View {
        VStack(alignment: .leading, spacing: 8) {
            FileTypeView()
            FileChartView()
            Divider()
            VStack(alignment: .leading, spacing: 5) {
                details
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var details: some View {
        let maliciousFlag = viewModel.lastAnalysisStats?.malicious ?? 0
        let totalFlag = numOfFlags(analysisStats: viewModel.lastAnalysisStats ?? defaultAnalysisStats)
        let inset: CGFloat = inMenuPanel ? 0 : 16

        Label("fileview.vendor.count \(maliciousFlag) \(totalFlag)", systemImage: getSystemImage())
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(getFlagCountColor())
            .padding(.horizontal, inset)

        Label("community.score.label \(viewModel.reputation ?? 0)", systemImage: "person.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(getCommunityScoreColor())
            .padding(.horizontal, inset)

        Label("analysis.date.label \(viewModel.lastAnalysisDate ?? "")", systemImage: "clock.arrow.circlepath")
            .symbolRenderingMode(.hierarchical)
            .padding(.horizontal, inset)

        Label("fileview.file.type \(viewModel.typeDescription ?? "n/a")", systemImage: "doc.circle")
            .symbolRenderingMode(.hierarchical)
            .padding(.horizontal, inset)

        HStack {
            Label("fileview.uniquesource.label \(viewModel.uniqueSources ?? 0)", systemImage: "mappin.circle")
                .symbolRenderingMode(.hierarchical)
            Spacer()
            HelpButtonItemView(
                helpHeadline: "fileview.uniquesource.help.headline",
                helpDetails: "fileview.uniquesource.help.details"
            )
        }
        .padding(.leading, inset)
        .padding(.trailing, 2)
    }

    // MARK: Private

    private let defaultAnalysisStats = FileAnalysisStats(malicious: 0,
                                                         suspicious: 0,
                                                         undetected: 63,
                                                         harmless: 0,
                                                         timeout: 0,
                                                         confirmedTimeout: 0,
                                                         failure: 0,
                                                         typeUnsupported: 14)

    /// Given a FileAnalysisStats, return the number of total flags
    private func numOfFlags(analysisStats: FileAnalysisStats) -> Int {
        return analysisStats.allFlags.sum { $0 }
    }

    /// return `checkmark.circle.fill` when malicious flag is 0, return `exclamationmark.triangle.fill` otherwise
    private func getSystemImage() -> String {
        return viewModel.lastAnalysisStats?.malicious == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    /// return color green if the number of malicious flags is 0, return color red otherwise
    private func getFlagCountColor() -> Color {
        return viewModel.lastAnalysisStats?.malicious == 0 ? .green : .red
    }

    /// return color orange if community score is lower than 0, return primary color otherwise
    private func getCommunityScoreColor() -> Color {
        return viewModel.reputation ?? 0 < 0 ? .orange : .primary
    }
}

#Preview {
    FileReportView()
        .frame(minWidth: 600, minHeight: 500)
}
