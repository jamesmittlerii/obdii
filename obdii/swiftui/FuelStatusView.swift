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
import Combine
import SwiftOBD2

struct FuelStatusView: View {

    @State private var viewModel = FuelStatusViewModel()
    @State private var interestToken = PIDInterestRegistry.shared.makeToken()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    content
                }
            }
            .navigationTitle("Fuel Control Status")
        }
        .onAppear {
            PIDInterestRegistry.shared.replace(
                pids: [.mode1(.fuelStatus)],
                for: interestToken
            )
        }
        .onDisappear {
            PIDInterestRegistry.shared.clear(token: interestToken)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var content: some View {

        // 1) Waiting state
        if viewModel.status == nil {
            waitingRow

        // 2) Loaded content
        } else {
            if let b1 = viewModel.bank1 {
                fuelRow(title: "Bank 1", description: b1.description)
                    .accessibilityLabel("Bank 1, \(b1.description)")
            }

            if let b2 = viewModel.bank2 {
                fuelRow(title: "Bank 2", description: b2.description)
                    .accessibilityLabel("Bank 2, \(b2.description)")
            }

            if !viewModel.hasAnyStatus {
                Label("No Fuel System Status Codes", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("No Fuel System Status Codes")
            }
        }
    }

    // MARK: - Rows

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
