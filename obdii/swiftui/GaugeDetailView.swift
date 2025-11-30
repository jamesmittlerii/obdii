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
import SwiftOBD2
import Combine
import Observation

struct GaugeDetailView: View {

    @State private var viewModel: GaugeDetailViewModel
    @State private var interestToken: UUID

    // Default initializer: create ViewModel and token on the main actor
    @MainActor
    init(pid: OBDPID) {
        _viewModel = State(initialValue: GaugeDetailViewModel(pid: pid))
        let token = PIDInterestRegistry.shared.makeToken()
        _interestToken = State(initialValue: token)
    }

    // Injectable initializer for tests/previews
    @MainActor
    init(viewModel: GaugeDetailViewModel, interestToken: UUID? = nil) {
        _viewModel = State(initialValue: viewModel)
        let token = interestToken ?? PIDInterestRegistry.shared.makeToken()
        _interestToken = State(initialValue: token)
    }

    // MARK: - Demand-driven PID interest
    private func updateInterest() {
        PIDInterestRegistry.shared.replace(
            pids: [viewModel.pid.pid],
            for: interestToken
        )
    }

    // MARK: - Body

    var body: some View {
        List {
            currentSection
            statisticsSection
            maxRangeSection
        }
        .navigationTitle(viewModel.pid.name)
        .onAppear { updateInterest() }
        .onDisappear { PIDInterestRegistry.shared.clear(token: interestToken) }
    }

    // MARK: - Sections

    private var currentSection: some View {
        Section(header: Text("Current")) {
            if let stats = viewModel.stats {
                Text(
                    viewModel.pid.formatted(
                        measurement: stats.latest,
                        includeUnits: true
                    )
                )
            } else {
                Text("— \(viewModel.pid.displayUnits)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Concrete Statistics section (always a Section so ViewInspector can find it)
    private var statisticsSection   : some View {
        Section(header: Text("Statistics")) {
            if let s = viewModel.stats {
                let unit = s.latest.unit
                Text("Min: \(formatted(value: s.min, unit: unit))")
                Text("Max: \(formatted(value: s.max, unit: unit))")
                Text("Samples: \(s.sampleCount)")
            } else {
                // Optionally show nothing or a placeholder; keeping it empty is fine for tests.
                EmptyView()
            }
        }
    }

    private var maxRangeSection: some View {
        Section(header: Text("Maximum Range")) {
            Text(viewModel.pid.displayRange)
        }
    }

    // MARK: - Helpers

    private func formatted(value: Double, unit: Unit) -> String {
        viewModel.pid.formatted(
            measurement: MeasurementResult(value: value, unit: unit),
            includeUnits: true
        )
    }
}

#Preview {
    NavigationStack {
        GaugeDetailView(
            pid: PIDStore.shared.enabledGauges.first
            ?? PIDStore.shared.pids.first!
        )
    }
}
