import SwiftOBD2
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

struct DTCDetailView: View {
  @State private var viewModel: DTCDetailViewModel

  init(viewModel: DTCDetailViewModel) {
    _viewModel = State(initialValue: viewModel)
  }

    // our view for the DTC details
  var body: some View {
    List {
      overviewSection
      descriptionSection
      causesSection
      remediesSection
    }
    .navigationTitle(viewModel.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var overviewSection: some View {
    Section(header: Text("Overview")) {
      ForEach(viewModel.overviewItems) { item in
        LabeledContent(item.label, value: item.value)
      }
    }
  }

  private var descriptionSection: some View {
    Section(header: Text("Description")) {
      Text(viewModel.descriptionText)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var causesSection: some View {
    Group {
      if !viewModel.causes.isEmpty {
        Section(header: Text("Potential Causes")) {
          ForEach(viewModel.causes, id: \.self) { cause in
            Text("• \(cause)")
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }

  private var remediesSection: some View {
    Group {
      if !viewModel.remedies.isEmpty {
        Section(header: Text("Possible Remedies")) {
          ForEach(viewModel.remedies, id: \.self) { remedy in
            Text("• \(remedy)")
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }
}

#Preview {
  let sample =
    troubleCodeDictionary["P0300"]
    ?? troubleCodeDictionary.values.first!

  NavigationStack {
    DTCDetailView(viewModel: DTCDetailViewModel(code: sample))
  }
}
