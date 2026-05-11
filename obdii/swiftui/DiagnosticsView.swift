/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI view for diagnostic trouble codes (DTCs)
 *
 * Displays active DTCs retrieved from the vehicle, organized by severity.
 * Shows a waiting state while loading, an empty state if no codes exist,
 * or grouped sections of codes when available. Tapping a code navigates
 * to a detailed view with causes and remedies.
 */
import SwiftUI

struct DiagnosticsView: View {

  @State private var viewModel: DiagnosticsViewModel

  // Default initializer preserves existing app behavior
  init() {
    _viewModel = State(initialValue: DiagnosticsViewModel())
  }

  // Injectable initializer for tests or previews
  init(viewModel: DiagnosticsViewModel) {
    _viewModel = State(initialValue: viewModel)
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Diagnostic Codes")
    }
    .onAppear { viewModel.onAppear() }
    .onDisappear { viewModel.onDisappear() }
  }

  @ViewBuilder
  private var content: some View {
    // 1) Waiting: codes == nil
    if viewModel.isWaiting {
      List {
        waitRow
      }

      // 2) Loaded but empty
    } else if viewModel.isEmpty {
      List {
        Text("No Diagnostic Trouble Codes")
          .foregroundStyle(.secondary)
      }

      // 3) Grouped sections
    } else {
      List {
        ForEach(viewModel.sections, id: \.title) { section in
          Section(header: Text(section.title)) {
            ForEach(section.items) { code in
              NavigationLink {
                DTCDetailView(viewModel: code.detailViewModel)
              } label: {
                codeRow(code)
              }
            }
          }
        }
      }
      .listStyle(.insetGrouped)
    }
  }

  private var waitRow: some View {
    HStack(spacing: 12) {
      ProgressView()
        .progressViewStyle(.circular)
      Text("Waiting for data…")
        .foregroundStyle(.secondary)
    }
    .accessibilityLabel("Waiting for data")
  }

    // show the DTC code
  private func codeRow(_ code: DiagnosticsViewModel.CodeRow) -> some View {
    HStack(spacing: 12) {
      Image(systemName: code.symbolName)

      VStack(alignment: .leading, spacing: 2) {
        Text(code.title)
          .lineLimit(1)

        Text(code.severityText)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  DiagnosticsView()
}
