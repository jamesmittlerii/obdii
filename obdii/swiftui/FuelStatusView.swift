/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI view for fuel system status
 *
 * Displays the current fuel control status for Bank 1 and Bank 2.
 * Shows status codes indicating whether fuel systems are in open loop,
 * closed loop, or other operational states. Includes waiting state for
 * initial data load and empty state if no status codes are available.
 */
import SwiftUI

// show the Fuel System status
struct FuelStatusView: View {

  @State private var viewModel: FuelStatusViewModel

  // Default initializer preserves existing app behavior
  init() {
    _viewModel = State(initialValue: FuelStatusViewModel())
  }

  // Injectable initializer for tests or previews
  init(viewModel: FuelStatusViewModel) {
    _viewModel = State(initialValue: viewModel)
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          content
        }
      }
      .navigationTitle("Fuel Control Status")
    }
    .onAppear { viewModel.onAppear() }
    .onDisappear { viewModel.onDisappear() }
  }

  @ViewBuilder
  private var content: some View {

    // 1) Waiting state
    if viewModel.isWaiting {
      waitingRow

      // 2) Loaded content
    } else {
      ForEach(viewModel.bankRows) { row in
        fuelRow(title: row.title, description: row.description)
          .accessibilityLabel(row.accessibilityLabel)
      }

      if !viewModel.hasAnyStatus {
        Label("No Fuel System Status Codes", systemImage: "info.circle")
          .foregroundStyle(.secondary)
          .accessibilityLabel("No Fuel System Status Codes")
      }
    }
  }

  private var waitingRow: some View {
    HStack(spacing: 12) {
      ProgressView()
        .progressViewStyle(.circular)
      Text("Waiting for data…")
        .foregroundStyle(.secondary)
    }
    .accessibilityLabel("Waiting for data")
  }

  private func fuelRow(title: String, description: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "fuelpump.fill")
        .foregroundStyle(.blue)
        .imageScale(.large)

      Text(title)

      Spacer()

      Text(description)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.trailing)
    }
  }
}

#Preview {
  FuelStatusView()
}
