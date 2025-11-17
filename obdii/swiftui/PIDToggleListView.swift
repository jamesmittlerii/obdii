/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
Swift UI view for enable/disable PIDs
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import SwiftUI

struct PIDToggleListView: View {
    // Use @State with @Observable view model
    @State private var viewModel = PIDToggleListViewModel()
    // Control programmatic presentation of the search UI
    @State private var isSearchPresented: Bool = false

    // Break up complex expressions to help the type checker
    private var enabledItems: [OBDPID] { viewModel.filteredEnabled }
    private var disabledItems: [OBDPID] { viewModel.filteredDisabled }

    var body: some View {
        Group {
            if isSearchPresented {
                listView
                    .id("search-on") // force rebuild so nav drawer syncs
                    .searchable(
                        text: $viewModel.searchText,
                        isPresented: $isSearchPresented,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: Text("Search PIDs")
                    )
            } else {
                listView
                    .id("search-off") // force rebuild so drawer fully disappears
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
            viewModel.searchText = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // iOS 17+ two-parameter onChange overload
        .onChange(of: isSearchPresented) { _, presented in
            // When search is dismissed (Cancel), clear query so full list returns
            if !presented {
                viewModel.searchText = ""
            }
        }
    }

    // Extracted list to avoid duplicating content when conditionally applying .searchable
    private var listView: some View {
        List {
            if !enabledItems.isEmpty {
                Section(header: Text("Enabled")) {
                    ForEach(enabledItems, id: \.id) { pid in
                        PIDToggleRow(
                            pid: pid,
                            isOn: toggleBinding(for: pid)
                        )
                    }
                    .onMove { source, destination in
                        viewModel.moveEnabled(fromOffsets: source, toOffset: destination)
                    }
                }
            }

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

            if enabledItems.isEmpty && disabledItems.isEmpty && !viewModel.searchText.isEmpty {
                Section {
                    Text("No results for “\(viewModel.searchText)”")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // Extracting this binding reduces type-checking complexity inside the ViewBuilder.
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
