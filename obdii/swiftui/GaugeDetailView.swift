import SwiftUI
import SwiftOBD2
import Combine
import Observation

struct GaugeDetailView: View {

    @State private var viewModel: GaugeDetailViewModel
    @State private var interestToken = PIDInterestRegistry.shared.makeToken()

    init(pid: OBDPID) {
        _viewModel = State(initialValue: GaugeDetailViewModel(pid: pid))
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
            statsSection
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

    private var statsSection: some View {
        Group {
            if let s = viewModel.stats {
                Section(header: Text("Statistics")) {
                    let unit = s.latest.unit
                    Text("Min: \(formatted(value: s.min, unit: unit))")
                    Text("Max: \(formatted(value: s.max, unit: unit))")
                    Text("Samples: \(s.sampleCount)")
                }
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
