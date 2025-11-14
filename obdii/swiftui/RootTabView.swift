/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
Swift UI view the root tabs - select any of the available main views
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

            NavigationStack {
                GaugesContainerView(connectionManager: .shared)
            }
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
