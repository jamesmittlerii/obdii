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
  @State private var viewModel: PIDToggleListViewModel

  // Controls presentation of search UI
  @State private var isSearchPresented: Bool = false

  @MainActor
  init() {
    _viewModel = State(initialValue: PIDToggleListViewModel())
  }

  @MainActor
  init(viewModel: PIDToggleListViewModel) {
    _viewModel = State(initialValue: viewModel)
  }

  var body: some View {
    @Bindable var viewModel = viewModel

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
      if !viewModel.enabledRows.isEmpty {
        Section(header: Text("Enabled")) {
          ForEach(viewModel.enabledRows) { row in
            PIDToggleRow(
              row: row,
              isOn: viewModel.binding(for: row.id)
            )
          }
          .onMove { source, dest in
            viewModel.moveEnabled(fromOffsets: source, toOffset: dest)
          }
          // Prevent index mismatches (and flicker) when search is active
          .moveDisabled(viewModel.isSearchActive)
        }
      }

      // Disabled Section
      if !viewModel.disabledRows.isEmpty {
        Section(header: Text("Disabled")) {
          ForEach(viewModel.disabledRows) { row in
            PIDToggleRow(
              row: row,
              isOn: viewModel.binding(for: row.id)
            )
          }
        }
      }

      // Empty search state
      if let emptySearchMessage = viewModel.emptySearchMessage {
        Section {
          Text(emptySearchMessage)
            .foregroundStyle(.secondary)
        }
      }
    }
    .listStyle(.insetGrouped)
  }

}

private struct PIDToggleRow: View {
  let row: PIDToggleListViewModel.Row
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) {
      VStack(alignment: .leading, spacing: 2) {
        Text(row.title)
        Text(row.subtitle)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityIdentifier(row.accessibilityIdentifier)
  }
}

#Preview {
  NavigationView { PIDToggleListView() }
}
