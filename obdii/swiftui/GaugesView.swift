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

  // Demand-driven polling token (set in @MainActor init to avoid nonisolated call)
  @State private var interestToken: UUID

  @MainActor
  init() {
    _viewModel = State(initialValue: GaugesViewModel())
    // Create the token on the main actor inside the initializer body
    let token = PIDInterestRegistry.shared.makeToken()
    _interestToken = State(initialValue: token)
  }

  // Injectable initializer for testing/mocking
  @MainActor
  init(viewModel: GaugesViewModel, interestToken: UUID? = nil) {
    _viewModel = State(initialValue: viewModel)
    // If no token provided, create one here on the main actor
    let token = interestToken ?? PIDInterestRegistry.shared.makeToken()
    _interestToken = State(initialValue: token)
  }

  // Adaptive layout: 2–4 columns depending on device width
  private let columns = [
    GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16, alignment: .top)
  ]

  // Identity list ignoring measurements
  private var tileIdentities: [TileIdentity] {
    viewModel.tiles.map { TileIdentity(id: $0.id, name: $0.pid.name) }
  }

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(viewModel.tiles) { tile in
          NavigationLink {
            GaugeDetailView(pid: tile.pid)
          } label: {
            GaugeTile(pid: tile.pid, measurement: tile.measurement)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("GaugeTile_\(tile.pid.id.uuidString)")
        }
      }
      .padding()
    }
    .onAppear {
      updateInterest()
    }
    .onDisappear {
      PIDInterestRegistry.shared.clear(token: interestToken)
    }
    .onChange(of: tileIdentities) {
      updateInterest()
    }
  }

  private func updateInterest() {
    // Demand-driven PID activation
    let commands: Set<OBDCommand> = Set(viewModel.tiles.map { $0.pid.pid })
    PIDInterestRegistry.shared.replace(pids: commands, for: interestToken)
  }
}

struct TileIdentity: Equatable {
  let id: UUID
  let name: String
}

private struct GaugeTile: View {
  let pid: OBDPID
  let measurement: MeasurementResult?

  var body: some View {
    VStack(spacing: 8) {

      RingGaugeView(pid: pid, measurement: measurement)
        .frame(width: 120, height: 98)

      Text(pid.label)
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
