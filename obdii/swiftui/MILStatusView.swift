import SwiftUI
import Combine
import SwiftOBD2

struct MILStatusView: View {

    // Stable view model instance
    @State private var viewModel = MILStatusViewModel()

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
                                .foregroundStyle(.orange)
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
                                    .foregroundStyle(.blue)
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
        if let ready {
            return ready ? "Ready" : "Not Ready"
        }
        return "—"
    }
}

#Preview {
    MILStatusView()
}
