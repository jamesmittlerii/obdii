/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI view for enabling/disabling gauge PIDs
 *
 * Displays all available PIDs in Enabled and Disabled sections.
 * Users can toggle PIDs on/off and reorder enabled gauges via drag-and-drop.
 * Includes search functionality to filter PIDs by name, label, or command.
 * Changes persist automatically through the PIDStore.
 */
import SwiftUI

struct PIDToggleListView: View {

  // Stable view model instance
  @State private var viewModel = PIDToggleListViewModel()

  // Controls presentation of search UI
  @State private var isSearchPresented: Bool = false

  // Break up for type checker clarity
  private var enabledItems: [OBDPID] { viewModel.filteredEnabled }
  private var disabledItems: [OBDPID] { viewModel.filteredDisabled }

  var body: some View {
    Group {
      if isSearchPresented {
        listView
          .id("search-on")  // force rebuild to sync presentation state
          .searchable(
            text: $viewModel.searchText,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: Text("Search PIDs")
          )
      } else {
        listView
          .id("search-off")  // removes drawer instantly
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          isSearchPresented = true
        } label: {
          Image(systemName: "magnifyingglass")
        }
        .accessibilityLabel("Search PIDs")
      }
    }
    .textInputAutocapitalization(.never)
    .disableAutocorrection(true)
    .onSubmit(of: .search) {
      viewModel.searchText = viewModel.searchText
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    .onChange(of: isSearchPresented) { _, presented in
      // When "Cancel" is hit, restore full list
      if !presented {
        viewModel.searchText = ""
      }
    }
    .onAppear {
      // If a search was active when navigating back, re-present the drawer
      if !viewModel.searchText.isEmpty {
        isSearchPresented = true
      }
    }
  }

  private var listView: some View {
    List {

      // Enabled Section
      if !enabledItems.isEmpty {
        Section(header: Text("Enabled")) {
          ForEach(enabledItems, id: \.id) { pid in
            PIDToggleRow(
              pid: pid,
              isOn: toggleBinding(for: pid)
            )
          }
          .onMove { source, dest in
            viewModel.moveEnabled(fromOffsets: source, toOffset: dest)
          }
          // Prevent index mismatches (and flicker) when search is active
          .moveDisabled(!viewModel.searchText.isEmpty)
        }
      }

      // Disabled Section
      if !disabledItems.isEmpty {
        Section(header: Text("Disabled")) {
          ForEach(disabledItems, id: \.id) { pid in
            PIDToggleRow(
              pid: pid,
              isOn: toggleBinding(for: pid)
            )
          }
        }
      }

      // Empty search state
      if enabledItems.isEmpty && disabledItems.isEmpty && !viewModel.searchText.isEmpty {
        Section {
          Text("No results for “\(viewModel.searchText)”")
            .foregroundStyle(.secondary)
        }
      }
    }
    .listStyle(.insetGrouped)
  }

  private func toggleBinding(for pid: OBDPID) -> Binding<Bool> {
    Binding<Bool>(
      get: { pid.enabled },
      set: { newValue in
        if let idx = viewModel.pids.firstIndex(where: { $0.id == pid.id }) {
          viewModel.toggle(at: idx, to: newValue)
        }
      }
    )
  }
}

private struct PIDToggleRow: View {
  let pid: OBDPID
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) {
      VStack(alignment: .leading, spacing: 2) {
        Text(pid.name)
        Text(pid.displayRange)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityIdentifier("PIDToggle_\(pid.id.uuidString)")
  }
}

#Preview {
  NavigationView { PIDToggleListView() }
}
