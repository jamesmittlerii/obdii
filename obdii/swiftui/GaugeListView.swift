/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI list view for live gauges
 *
 * Alternative list-based presentation of enabled gauges showing current values.
 * Each row displays gauge name, value range, and current reading with color coding.
 * Uses demand-driven polling for visible gauge data.
 * Tapping a row navigates to detailed statistics.
 */
import SwiftUI
import SwiftOBD2

struct GaugeListView: View {

    @ObservedObject private var connectionManager = OBDConnectionManager.shared
    @State private var viewModel = GaugesViewModel()
    @State private var interestToken = PIDInterestRegistry.shared.makeToken()

    // Used to detect changes in the list of PIDs we should subscribe to.
    private var tileIdentities: [TileIdentity] {
        viewModel.tiles.map { TileIdentity(id: $0.id, name: $0.pid.name) }
    }

    var body: some View {
        List {
            Section(header: Text("Gauges")) {
                ForEach(viewModel.tiles) { tile in
                    NavigationLink {
                        GaugeDetailView(pid: tile.pid)
                    } label: {
                        tileRow(tile)
                    }
                }
            }
        }
        .navigationTitle("Live Gauges")
        .onAppear { updateInterest() }
        .onDisappear { PIDInterestRegistry.shared.clear(token: interestToken) }
        .onChange(of: tileIdentities) {
            updateInterest()
        }
    }

    // MARK: - UI Row

    private func tileRow(_ tile: GaugesViewModel.Tile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tile.pid.name)
                    .font(.headline)

                Text(tile.pid.displayRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(currentValueText(for: tile))
                .font(.title3.monospacedDigit())
                .foregroundStyle(currentValueColor(for: tile))
                .accessibilityLabel("\(tile.pid.name) value")
        }
        .contentShape(Rectangle())
    }

    // MARK: - Demand-driven PID interest

    private func updateInterest() {
        let commands: Set<OBDCommand> = Set(viewModel.tiles.map { $0.pid.pid })
        PIDInterestRegistry.shared.replace(pids: commands, for: interestToken)
    }

    // MARK: - Value Formatting

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
    NavigationStack {
        GaugeListView()
    }
}
