import SwiftOBD2
import Combine
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

@MainActor
struct GaugeListView: View {

  @State private var viewModel: GaugesViewModel
  @State private var pids: [OBDPID] = []
  @State private var cancellables = Set<AnyCancellable>()

  // Default initializer preserves existing behavior
  @MainActor
  init() {
    _viewModel = State(initialValue: GaugesViewModel())
  }

  // Injectable initializer for testing/mocking
  @MainActor
  init(viewModel: GaugesViewModel) {
    _viewModel = State(initialValue: viewModel)
  }

  var body: some View {
    List {
      let enabled = pids.filter { $0.kind == .gauge && $0.enabled }
      ForEach(enabled, id: \.id) { pid in
        if let tile = viewModel.displayTiles.first(where: { $0.id == pid.id }) {
          NavigationLink {
            GaugeDetailView(viewModel: tile.detailViewModel)
          } label: {
            tileRow(tile)
          }
        } else {
          HStack {
            Text("…")
            Spacer()
          }
        }
      }
      .onMove { source, destination in
        PIDStore.shared.moveEnabled(fromOffsets: source, toOffset: destination)
      }
    }
    .navigationTitle("Live Gauges")
    .onAppear {
      viewModel.onAppear()
      PIDStore.shared.pidsPublisher
        .receive(on: RunLoop.main)
        .sink { newPids in
          self.pids = newPids
        }
        .store(in: &cancellables)
    }
    .onDisappear { viewModel.onDisappear() }
  }

  private func tileRow(_ tile: GaugesViewModel.DisplayTile) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(tile.title)
          .font(.headline)

        Text(tile.subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Text(tile.valueText)
        .font(.title3.monospacedDigit())
        .foregroundStyle(tile.valueColor)
        .accessibilityLabel(tile.valueAccessibilityLabel)
    }
    .contentShape(Rectangle())
  }
}

#Preview {
  NavigationStack {
    GaugeListView()
  }
}
