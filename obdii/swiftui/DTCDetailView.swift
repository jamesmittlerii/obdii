/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI detail view for a diagnostic trouble code
 *
 * Displays comprehensive information about a selected DTC including
 * code, title, severity, description, potential causes, and possible remedies.
 * Organized into sections for easy readability and troubleshooting.
 */
import SwiftUI
import SwiftOBD2

struct DTCDetailView: View {
    let code: TroubleCodeMetadata

    var body: some View {
        List {
            overviewSection
            descriptionSection
            causesSection
            remediesSection
        }
        .navigationTitle(code.code)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var overviewSection: some View {
        Section(header: Text("Overview")) {
            LabeledContent("Code", value: code.code)
            LabeledContent("Title", value: code.title)
            LabeledContent("Severity", value: code.severity.rawValue)
        }
    }

    private var descriptionSection: some View {
        Section(header: Text("Description")) {
            Text(code.description)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var causesSection: some View {
        Group {
            if !code.causes.isEmpty {
                Section(header: Text("Potential Causes")) {
                    ForEach(code.causes, id: \.self) { cause in
                        Text("• \(cause)")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var remediesSection: some View {
        Group {
            if !code.remedies.isEmpty {
                Section(header: Text("Possible Remedies")) {
                    ForEach(code.remedies, id: \.self) { remedy in
                        Text("• \(remedy)")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

#Preview {
    let sample = troubleCodeDictionary["P0300"]
        ?? troubleCodeDictionary.values.first!

    NavigationStack {
        DTCDetailView(code: sample)
    }
}
