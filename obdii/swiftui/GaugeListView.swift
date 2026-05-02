import SwiftOBD2
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
      Section(header: Text("Gauges")) {
        ForEach(viewModel.displayTiles) { tile in
          NavigationLink {
            GaugeDetailView(viewModel: tile.detailViewModel)
          } label: {
            tileRow(tile)
          }
        }
      }
    }
    .navigationTitle("Live Gauges")
    .onAppear { viewModel.onAppear() }
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
