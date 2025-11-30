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
import SwiftOBD2

struct MILStatusView: View {

    // Stable view model instance
    @State private var viewModel: MILStatusViewModel
    
    // Default initializer preserves existing app behavior
    init() {
        _viewModel = State(initialValue: MILStatusViewModel())
    }

    // Injectable initializer for tests or previews
    init(viewModel: MILStatusViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // Demand-driven PID interest
    @State private var interestToken: UUID = PIDInterestRegistry.shared.makeToken()

    var body: some View {
        NavigationStack {
            List {

                // MARK: - MIL Summary Section
                Section(header: Text("Malfunction Indicator Lamp")) {
                    if viewModel.status == nil {
                        // Waiting for first payload
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("Waiting for data…")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Waiting for data")

                    } else if viewModel.hasStatus {
                        HStack(spacing: 12) {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundStyle(viewModel.status!.milOn ? .orange : .blue )
                                .imageScale(.large)

                            Text(viewModel.headerText)
                                .font(.headline)
                        }
                        .accessibilityLabel(viewModel.headerText)

                    } else {
                        Label("No MIL Status", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Readiness Section
                if viewModel.status != nil {
                    Section(header: Text("Readiness Monitors")) {
                        ForEach(viewModel.sortedSupportedMonitors, id: \.name) { monitor in
                            HStack(spacing: 12) {
                                Image(systemName: "gauge")
                                    .foregroundStyle(monitor.ready ? .blue : .orange)
                                    .imageScale(.medium)

                                Text(monitor.name)

                                Spacer()

                                Text(monitor.readyText)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("\(monitor.name), \(monitor.readyText)")
                        }
                    }
                }
            }
            .navigationTitle("MIL Status")
        }
        .onAppear {
            PIDInterestRegistry.shared.replace(pids: [.mode1(.status)], for: interestToken)
        }
        .onDisappear {
            PIDInterestRegistry.shared.clear(token: interestToken)
        }
    }
}

private extension ReadinessMonitor {
    var readyText: String {
        // ready is a non-optional Bool per the compiler error.
        return ready ? "Ready" : "Not Ready"
    }
}

#Preview {
    MILStatusView()
}
