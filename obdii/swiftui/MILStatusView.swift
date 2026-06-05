/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI view for MIL (Malfunction Indicator Lamp) status
 *
 * Displays Check Engine Light status including whether MIL is on/off,
 * DTC count, and readiness monitor status for emissions systems.
 * Shows waiting state while loading and organized sections for MIL
 * summary and individual readiness monitors.
 */
import SwiftUI

struct MILStatusView: View {

  // Stable view model instance
  @State private var viewModel: MILStatusViewModel
  private let onSummaryTap: () -> Void

  // Default initializer preserves existing app behavior
  init(onSummaryTap: @escaping () -> Void = {
    // Standalone MIL tab: scaffold wires summary navigation when embedded.
  }) {
    _viewModel = State(initialValue: MILStatusViewModel())
    self.onSummaryTap = onSummaryTap
  }

  // Injectable initializer for tests or previews
  init(viewModel: MILStatusViewModel, onSummaryTap: @escaping () -> Void = {
    // Previews/tests omit navigation unless they inject a handler.
  }) {
    _viewModel = State(initialValue: viewModel)
    self.onSummaryTap = onSummaryTap
  }

  var body: some View {
    NavigationStack {
      List {

        Section(header: Text("Malfunction Indicator Lamp")) {
          if viewModel.isWaiting {
            // Waiting for first payload
            HStack(spacing: 12) {
              ProgressView()
                .progressViewStyle(.circular)
              Text("Waiting for data…")
                .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Waiting for data")

          } else if let summary = viewModel.summaryRow {
            Button(action: onSummaryTap) {
              HStack(spacing: 12) {
                Image(systemName: summary.symbolName)
                  .foregroundStyle(summary.symbolColor == "orange" ? .orange : .blue)
                  .imageScale(.large)

                Text(summary.text)
                  .font(.headline)

                Spacer(minLength: 0)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(summary.text)

          } else {
            Label("No MIL Status", systemImage: "info.circle")
              .foregroundStyle(.secondary)
          }
        }

        if viewModel.hasStatus {
          Section(header: Text("Readiness Monitors")) {
            ForEach(viewModel.monitorRows) { monitor in
              HStack(spacing: 12) {
                Image(systemName: monitor.symbolName)
                  .foregroundStyle(monitor.symbolColor == "blue" ? .blue : .orange)
                  .imageScale(.medium)

                Text(monitor.name)

                Spacer()

                Text(monitor.readyText)
                  .foregroundStyle(.secondary)
              }
              .accessibilityLabel(monitor.accessibilityLabel)
            }
          }
        }
      }
      .navigationTitle("MIL Status")
    }
    .onAppear { viewModel.onAppear() }
    .onDisappear { viewModel.onDisappear() }
  }
}

#Preview {
  MILStatusView()
}
