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
    @StateObject private var viewModel = PIDToggleListViewModel()

    var body: some View {
        List {
            // Enabled section
            let enabledItems: [OBDPID] = viewModel.filteredEnabled
            if !enabledItems.isEmpty {
                Section(header: Text("Enabled")) {
                    ForEach(enabledItems, id: \.id) { pid in
                        PIDToggleRow(
                            pid: pid,
                            isOn: Binding(
                                get: { pid.enabled },
                                set: { newValue in
                                    // Find the current index in the master array to toggle
                                    if let idx = viewModel.pids.firstIndex(where: { $0.id == pid.id }) {
                                        viewModel.toggle(at: idx, to: newValue)
                                    }
                                }
                            )
                        )
                    }
                    .onMove { source, destination in
                        // Map source/destination within the enabled subset to the view model’s move API
                        viewModel.moveEnabled(fromOffsets: source, toOffset: destination)
                    }
                }
            }

            // Disabled section
            let disabledItems: [OBDPID] = viewModel.filteredDisabled
            if !disabledItems.isEmpty {
                Section(header: Text("Disabled")) {
                    ForEach(disabledItems, id: \.id) { pid in
                        PIDToggleRow(
                            pid: pid,
                            isOn: Binding(
                                get: { pid.enabled },
                                set: { newValue in
                                    if let idx = viewModel.pids.firstIndex(where: { $0.id == pid.id }) {
                                        viewModel.toggle(at: idx, to: newValue)
                                    }
                                }
                            )
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $viewModel.searchText, prompt: "Search PIDs")
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
