/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
Swift UI view for the individual gauge detail (textual)
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import SwiftUI
import SwiftOBD2
import Combine


struct GaugeDetailView: View {
    @StateObject private var viewModel: GaugeDetailViewModel
    // Demand-driven polling token
    @State private var interestToken: UUID = PIDInterestRegistry.shared.makeToken()

    init(pid: OBDPID, connectionManager: OBDConnectionManager) {
        _viewModel = StateObject(wrappedValue: GaugeDetailViewModel(pid: pid, connectionManager: connectionManager))
    }
    
    private func updateInterest() {
        // Register interest for this gauge's command
        let commands: Set<OBDCommand> = [viewModel.pid.pid]
        PIDInterestRegistry.shared.replace(pids: commands, for: interestToken)
    }

    var body: some View {
        List {
            Section(header: Text("Current")) {
                if let s = viewModel.stats {
                    Text(viewModel.pid.formatted(measurement: s.latest, includeUnits: true))
                } else {
                    Text("— \(viewModel.pid.displayUnits)")
                        .foregroundColor(.secondary)
                }
            }

            if let s = viewModel.stats {
                Section(header: Text("Statistics")) {
                    Text("Min: \(viewModel.pid.formatted(measurement: MeasurementResult(value: s.min, unit: s.latest.unit), includeUnits: true))")
                    Text("Max: \(viewModel.pid.formatted(measurement: MeasurementResult(value: s.max, unit: s.latest.unit), includeUnits: true))")
                    Text("Samples: \(s.sampleCount)")
                }
            }

            Section(header: Text("Maximum Range")) {
                Text(viewModel.pid.displayRange)
            }
        }
        .navigationTitle(viewModel.pid.name)
        .onAppear {
            updateInterest()
        }
        .onDisappear {
            PIDInterestRegistry.shared.clear(token: interestToken)
        }
    }
}

#Preview {
    NavigationView {
        GaugeDetailView(
            pid: PIDStore.shared.enabledGauges.first ?? PIDStore.shared.pids.first!,
            connectionManager: OBDConnectionManager.shared
        )
    }
}
