/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI container for gauges display mode selection
 *
 * Provides a segmented picker to switch between Grid and List viewing modes.
 * Persists user's preferred display mode across app sessions via @AppStorage.
 * Wraps GaugesView (grid) and GaugeListView (list) alternatives.
 */
import SwiftUI
import SwiftOBD2

enum GaugesDisplayMode: String, CaseIterable, Identifiable {
    case gauges
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gauges: return "Gauges"
        case .list:   return "List"
        }
    }
}

struct GaugesContainerView: View {

    // Persisted UI state
    @AppStorage("gaugesDisplayMode")
    private var storedMode: String = GaugesDisplayMode.gauges.rawValue

    // Global connection manager reference (no need to pass in)
    @ObservedObject private var connectionManager = OBDConnectionManager.shared

    private var modeBinding: Binding<GaugesDisplayMode> {
        Binding(
            get: { GaugesDisplayMode(rawValue: storedMode) ?? .gauges },
            set: { storedMode = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {

            // Display mode picker
            Picker("Display Mode", selection: modeBinding) {
                ForEach(GaugesDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)

            // Main content area
            Group {
                switch GaugesDisplayMode(rawValue: storedMode) ?? .gauges {
                case .gauges:
                    GaugesView()
                case .list:
                    GaugeListView()
                }
            }
        }
        .navigationTitle(titleForCurrentMode)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleForCurrentMode: String {
        (GaugesDisplayMode(rawValue: storedMode) ?? .gauges).title
    }
}

#Preview {
    NavigationStack {
        GaugesContainerView()
    }
}
