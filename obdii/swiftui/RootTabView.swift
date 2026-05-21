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
  private enum Tab: Hashable {
    case settings
    case gauges
    case fuel
    case mil
    case diagnostics
  }

  @State private var selectedTab: Tab = .settings

  var body: some View {
    TabView(selection: $selectedTab) {

      SettingsView()
        .tag(Tab.settings)
        .tabItem {
          Label("Settings", systemImage: "gear")
        }

      NavigationStack {
        GaugesContainerView()
      }
      .tag(Tab.gauges)
      .tabItem {
        Label("Gauges", systemImage: "gauge")
      }

      NavigationStack {
        FuelStatusView()
      }
      .tag(Tab.fuel)
      .tabItem {
        Label("Fuel", systemImage: "fuelpump.fill")
      }

      NavigationStack {
        MILStatusView {
          selectedTab = .diagnostics
        }
      }
      .tag(Tab.mil)
      .tabItem {
        Label("MIL", systemImage: "engine.combustion.fill")
      }

      NavigationStack {
        DiagnosticsView()
      }
      .tag(Tab.diagnostics)
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
