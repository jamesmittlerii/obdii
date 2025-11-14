/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
Swift UI view for showing a textual list of gauges
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import SwiftUI
import SwiftOBD2

struct GaugeListView: View {
    @ObservedObject var connectionManager: OBDConnectionManager
    @StateObject private var viewModel: GaugesViewModel

    init(connectionManager: OBDConnectionManager) {
        self.connectionManager = connectionManager
        _viewModel = StateObject(wrappedValue: GaugesViewModel(connectionManager: connectionManager, pidStore: .shared))
    }

    var body: some View {
        List {
            Section(header: Text("Gauges")) {
                ForEach(viewModel.tiles) { tile in
                    NavigationLink(destination: GaugeDetailView(pid: tile.pid, connectionManager: connectionManager)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tile.pid.name)
                                    .font(.headline)
                                Text(tile.pid.displayRange)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(currentValueText(for: tile))
                                .font(.title3.monospacedDigit())
                                .foregroundColor(currentValueColor(for: tile))
                                .accessibilityLabel("\(tile.pid.name) value")
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .navigationTitle("Live Gauges")
    }

    private func currentValueText(for tile: GaugesViewModel.Tile) -> String {
        if let m = tile.measurement {
            return tile.pid.formatted(measurement: m, includeUnits: true)
        } else {
            return "— \(tile.pid.displayUnits)"
        }
    }

    private func currentValueColor(for tile: GaugesViewModel.Tile) -> Color {
        if let m = tile.measurement {
            return tile.pid.color(for: m.value)
        } else {
            return .secondary
        }
    }
}

#Preview {
    NavigationView {
        GaugeListView(connectionManager: .shared)
    }
}
