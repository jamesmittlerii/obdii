import SwiftOBD2
/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI grid view for live gauge tiles
 *
 * Displays enabled gauges in an adaptive grid (2-4 columns based on width).
 * Each tile shows a ring gauge visualization with current value and units.
 * Uses demand-driven polling to request only visible gauge data.
 * Tapping a tile navigates to detailed statistics view.
 */
import SwiftUI
import UIKit

@MainActor
struct GaugesView: View {

  // Stable observable view model instance
  @State private var viewModel: GaugesViewModel

  @MainActor
  init() {
    _viewModel = State(initialValue: GaugesViewModel())
  }

  // Injectable initializer for testing/mocking
  @MainActor
  init(viewModel: GaugesViewModel) {
    _viewModel = State(initialValue: viewModel)
  }

  // Adaptive layout: 2–4 columns depending on device width
  private let columns = [
    GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16, alignment: .top)
  ]

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(viewModel.displayTiles) { tile in
          NavigationLink {
            GaugeDetailView(viewModel: tile.detailViewModel)
          } label: {
            GaugeTile(tile: tile)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(tile.tileAccessibilityIdentifier)
        }
      }
      .padding()
    }
    .onAppear {
      viewModel.onAppear()
    }
    .onDisappear {
      viewModel.onDisappear()
    }
  }
}

struct TileIdentity: Equatable {
  let id: UUID
  let name: String
}

private struct GaugeTile: View {
  let tile: GaugesViewModel.DisplayTile

  var body: some View {
    VStack(spacing: 8) {


      RingGaugeView(model: tile.ring)
        .frame(width: 120, height: 120)

      Text(tile.shortTitle)
        .font(.headline)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(UIColor.secondarySystemBackground))
    )
  }
}

#Preview {
  NavigationStack {
    GaugesView()
  }
}
