/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
Swift UI view for a grid of gauges
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import SwiftUI
import Combine
import SwiftOBD2
import UIKit

@MainActor
struct GaugesView: View {
    @StateObject private var viewModel: GaugesViewModel

    // Keep the initializer signature compatible with existing call sites
    init(connectionManager: OBDConnectionManager, pidStore: PIDStore? = nil) {
        let resolvedStore = pidStore ?? PIDStore.shared
        _viewModel = StateObject(wrappedValue: GaugesViewModel(connectionManager: connectionManager, pidStore: resolvedStore))
    }

    // Adaptive grid: 2–4 columns depending on width
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.tiles) { tile in
                    NavigationLink {
                        GaugeDetailView(pid: tile.pid, connectionManager: .shared)
                    } label: {
                        GaugeTile(pid: tile.pid, measurement: tile.measurement)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("GaugeTile_\(tile.pid.id.uuidString)")
                }
            }
            .padding()
        }
    }
}

private struct GaugeTile: View {
    let pid: OBDPID
    let measurement: MeasurementResult?

    var body: some View {
        VStack(spacing: 0) {
            // SwiftUI gauge view replacing the UIImage-based drawing for app UI
            RingGaugeView(pid: pid, measurement: measurement)
                .frame(width: 120, height: 120)

            // Title
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

    private func subtitleText() -> String {
        if let m = measurement {
            return pid.formatted(measurement: m, includeUnits: true)
        } else {
            return "— \(pid.displayUnits)"
        }
    }
}

#Preview {
    NavigationStack {
        GaugesView(connectionManager: .shared, pidStore: .shared)
    }
}
