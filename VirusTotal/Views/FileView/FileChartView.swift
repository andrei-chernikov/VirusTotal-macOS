//
//  FileChartView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-03.
//

import SwiftUI
import Charts

struct FileChartView: View {
    private var viewModel = FileViewModel.shared

    @Environment(\.inMenuPanel) private var inMenuPanel
    @State private var animateChart = false

    var body: some View {
        if inMenuPanel {
            HStack(alignment: .center, spacing: 12) {
                chart
                    .chartLegend(.hidden)
                    .chartForegroundStyleScale(domain: flagStats.map { $0.type.nslocalized }, range: chartColors)
                    .frame(width: 100, height: 100)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(flagStats.indices, id: \.self) { index in
                        let flag = flagStats[index]
                        HStack(spacing: 6) {
                            Circle()
                                .fill(chartColors[index])
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                            Text(flag.type.nslocalized)
                            Spacer(minLength: 4)
                            Text(flag.number, format: .number)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .font(.caption)
            }
        } else {
            chart.chartLegend(position: .leading, alignment: .center)
        }
    }

    private let chartColors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .yellow, .gray]

    private var chart: some View {
        Chart(flagStats, id: \.type) { element in
            SectorMark(
                angle: .value(String("Flags"), inMenuPanel || animateChart ? element.number : 1),
                innerRadius: .ratio(0.618),
                angularInset: inMenuPanel ? 1 : 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(by: .value(String("Type"), element.type.nslocalized))
        }
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                let frame = chartProxy.plotFrame.map { geometry[$0] } ?? .zero
                VStack(spacing: inMenuPanel ? 2 : 8) {
                    Text(String(viewModel.lastAnalysisStats?.malicious ?? 0))
                        .font(inMenuPanel ? .headline : .largeTitle.bold())
                        .foregroundStyle(getFontColor())
                    Text(verbatim: "/ \(numOfFlags(analysisStats: viewModel.lastAnalysisStats ?? defaultAnalysisStats))")
                        .font(inMenuPanel ? .caption : .title2)
                        .foregroundStyle(.secondary)
                }
                .position(x: frame.midX, y: frame.midY)
            }
        }
        .animation(.smooth, value: animateChart)
        .onAppear {
            if !inMenuPanel { animateChart = true }
        }
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

    private var flagStats: [FlagStats] {
        return [
            .init(type: "flag.type.unsupported",
                  number: viewModel.lastAnalysisStats?.typeUnsupported ?? 0),
            .init(type: "flag.undetected",
                  number: viewModel.lastAnalysisStats?.undetected ?? 0),
            .init(type: "flag.suspicious",
                  number: viewModel.lastAnalysisStats?.suspicious ?? 0),
            .init(type: "flag.failure",
                  number: viewModel.lastAnalysisStats?.failure ?? 0),
            .init(type: "flag.malicious",
                  number: viewModel.lastAnalysisStats?.malicious ?? 0),
            .init(type: "flag.harmless",
                  number: viewModel.lastAnalysisStats?.harmless ?? 0),
            .init(type: "flag.timeout",
                  number: viewModel.lastAnalysisStats?.timeout ?? 0),
            .init(type: "flag.confirmed.timeout",
                  number: viewModel.lastAnalysisStats?.confirmedTimeout ?? 0)
        ]
    }

    /// Given an FileAnalysisStats, return the total number of flags
    private func numOfFlags(analysisStats: FileAnalysisStats) -> Int {
        return analysisStats.allFlags.sum { $0 }
    }

    /// return color green if the number of malicious flags is 0, return color red otherwise
    private func getFontColor() -> Color {
        return viewModel.lastAnalysisStats?.malicious == 0 ? .green : .red
    }
}

#Preview {
    FileChartView()
    .frame(width: 290, height: 170)
}
