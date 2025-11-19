/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Root tab view for the phone UI
 *
 * Displays the main tab interface with five tabs:
 * Settings, Gauges, Fuel System Status, MIL Status, and Diagnostic Codes.
 * Each tab contains a SwiftUI NavigationStack for drill-down navigation.
 */
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {

            // MARK: - Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

            // MARK: - Gauges (Grid/List)
            NavigationStack {
                GaugesContainerView()
            }
            .tabItem {
                Label("Gauges", systemImage: "gauge")
            }

            // MARK: - Fuel System Status
            NavigationStack {
                FuelStatusView()
            }
            .tabItem {
                Label("Fuel", systemImage: "fuelpump.fill")
            }

            // MARK: - MIL Status
            NavigationStack {
                MILStatusView()
            }
            .tabItem {
                Label("MIL", systemImage: "engine.combustion.fill")
            }

            // MARK: - Diagnostic Trouble Codes
            NavigationStack {
                DiagnosticsView()
            }
            .tabItem {
                Label("DTCs", systemImage: "wrench.and.screwdriver")
            }
        }
        // Ensures icons appear on iPad just like iPhone
        .tabViewStyle(.automatic)
    }
}

#Preview {
    RootTabView()
}
