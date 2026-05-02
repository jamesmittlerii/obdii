import Observation
/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI detail view for a single gauge/PID
 *
 * Displays comprehensive statistics for a selected parameter including
 * current value, minimum/maximum observed, sample count, and typical range.
 * Uses demand-driven polling to request only this specific PID data.
 */
import SwiftUI

struct GaugeDetailView: View {

  @State private var viewModel: GaugeDetailViewModel

  @MainActor
  init(viewModel: GaugeDetailViewModel) {
    _viewModel = State(initialValue: viewModel)
  }

  var body: some View {
    List {
      currentSection
      statisticsSection
      maxRangeSection
    }
    .navigationTitle(viewModel.title)
    .onAppear { viewModel.onAppear() }
    .onDisappear { viewModel.onDisappear() }
  }

  private var currentSection: some View {
    Section(header: Text("Current")) {
      Text(viewModel.currentValueText)
        .foregroundStyle(viewModel.stats == nil ? .secondary : .primary)
    }
  }

  // Concrete Statistics section (always a Section so ViewInspector can find it)
  private var statisticsSection: some View {
    Section(header: Text("Statistics")) {
      ForEach(viewModel.statisticsRows) { row in
        Text(row.text)
      }
    }
  }

  private var maxRangeSection: some View {
    Section(header: Text("Maximum Range")) {
      Text(viewModel.maximumRangeText)
    }
  }
}

#Preview {
  NavigationStack {
    GaugeDetailView(viewModel: GaugeDetailViewModel(pid: PIDStore.shared.enabledGauges.first ?? PIDStore.shared.pids.first!))
  }
}
