import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

            GaugesView()
                .tabItem {
                    Label("Gauges", systemImage: "gauge")
                }

            FuelStatusView()
                .tabItem {
                    Label("Fuel", systemImage: "fuelpump.fill")
                }

            MILStatusView()
                .tabItem {
                    Label("MIL", systemImage: "engine.combustion.fill")
                }

            DiagnosticsView()
                .tabItem {
                    Label("DTCs", systemImage: "wrench.and.screwdriver")
                }
        }
        // Force the standard tab bar style on all devices to ensure icons are visible.
        .tabViewStyle(.automatic)
    }
}

#Preview {
    RootTabView()
}
