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
  private enum Tab: Int, Hashable, CaseIterable {
    case settings = 0
    case gauges = 1
    case fuel = 2
    case mil = 3
    case diagnostics = 4
  }

  @ObservedObject private var config = ConfigData.shared
  @State private var selectedTab: Tab = .settings
  @State private var showOnboarding = !ConfigData.shared.hasCompletedOnboarding
  @State private var onboardingPageIndex = 0
  @State private var showGaugePicker = false

  init(testOnboardingState showOnboarding: Bool? = nil, pageIndex: Int = 0) {
    _selectedTab = State(initialValue: .settings)
    _showOnboarding = State(
      initialValue: showOnboarding ?? !ConfigData.shared.hasCompletedOnboarding
    )
    _onboardingPageIndex = State(initialValue: pageIndex)
    _showGaugePicker = State(initialValue: false)
  }

  private var tabSelection: Binding<Tab> {
    Binding(
      get: { selectedTab },
      set: { newTab in
        guard !showOnboarding else { return }
        selectedTab = newTab
      }
    )
  }

  private var interactionsEnabled: Bool { !showOnboarding }

  private var onboardingNavHighlight: Int? {
    showOnboarding ? OnboardingScreenModel.highlightedNavTab(onboardingPageIndex) : nil
  }

  var body: some View {
    ZStack {
      TabView(selection: tabSelection) {
        SettingsView(onShowIntroAgain: restartOnboarding)
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
            guard interactionsEnabled else { return }
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
      .tabViewStyle(.automatic)

      if showGaugePicker {
        gaugePickerOverlay
      }

      if showOnboarding {
        OnboardingContentScrim(
          pageIndex: onboardingPageIndex,
          onPageIndexChange: setOnboardingPageIndex,
          onComplete: completeOnboarding
        )
      }
    }
    .overlay(alignment: .bottom) {
      if showOnboarding {
        OnboardingNavHighlight(highlightedIndex: onboardingNavHighlight)
      }
    }
    .onAppear {
      syncOnboardingPreview()
    }
    .onChange(of: onboardingPageIndex) { _, _ in
      syncOnboardingPreview()
    }
    .onChange(of: showOnboarding) { _, isShowing in
      if isShowing {
        syncOnboardingPreview()
      } else {
        showGaugePicker = false
      }
    }
  }

  private var gaugePickerOverlay: some View {
    NavigationStack {
      PIDToggleListView()
        .navigationTitle("Gauges")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              if !showOnboarding {
                showGaugePicker = false
              }
            } label: {
              Image(systemName: "chevron.left")
            }
            .disabled(showOnboarding)
          }
        }
    }
    .background(Color(.systemGroupedBackground))
  }

  private func setOnboardingPageIndex(_ index: Int) {
    onboardingPageIndex = index
    syncOnboardingPreview()
  }

  private func syncOnboardingPreview() {
    guard showOnboarding else {
      showGaugePicker = false
      return
    }

    if OnboardingScreenModel.showGaugePicker(onboardingPageIndex) {
      selectedTab = .settings
      showGaugePicker = true
    } else {
      showGaugePicker = false
      if let tabIndex = OnboardingScreenModel.previewTabIndex(onboardingPageIndex),
        let tab = Tab(rawValue: tabIndex)
      {
        selectedTab = tab
      }
    }
  }

  private func restartOnboarding() {
    onboardingPageIndex = 0
    showOnboarding = true
    syncOnboardingPreview()
  }

  private func completeOnboarding(startDemo: Bool) {
    config.hasCompletedOnboarding = true
    showOnboarding = false
    showGaugePicker = false

    guard startDemo else { return }

    config.connectionType = .demo
    selectedTab = .gauges
    Task { await OBDConnectionManager.shared.connect() }
  }
}

#Preview {
  RootTabView()
}
