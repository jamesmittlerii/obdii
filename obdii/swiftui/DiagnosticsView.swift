import SwiftUI
import SwiftOBD2

struct DiagnosticsView: View {

    @State private var viewModel = DiagnosticsViewModel()
    @State private var interestToken = PIDInterestRegistry.shared.makeToken()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Diagnostic Codes")
        }
        .onAppear {
            PIDInterestRegistry.shared.replace(
                pids: [.mode3(.GET_DTC)],
                for: interestToken
            )
        }
        .onDisappear {
            PIDInterestRegistry.shared.clear(token: interestToken)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        // 1) Waiting: codes == nil
        if viewModel.codes == nil {
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
                        ForEach(section.items, id: \.code) { code in
                            NavigationLink {
                                DTCDetailView(code: code)
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

    // MARK: - Rows

    private var waitRow: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Waiting for data…")
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Waiting for data")
    }

    private func codeRow(_ code: TroubleCodeMetadata) -> some View {
        HStack(spacing: 12) {
            Image(systemName: imageName(for: code.severity))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(code.code) • \(code.title)")
                    .lineLimit(1)

                Text(code.severity.rawValue)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    DiagnosticsView()
}
