import SwiftUI
import SwiftOBD2

enum GaugesDisplayMode: String, CaseIterable, Identifiable {
    case gauges
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gauges: return "Gauges"
        case .list: return "List"
        }
    }
}

struct GaugesContainerView: View {
    @State private var mode: GaugesDisplayMode = .gauges
    @ObservedObject var connectionManager: OBDConnectionManager

    var body: some View {
        VStack {
            Picker("Display Mode", selection: $mode) {
                ForEach(GaugesDisplayMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            Group {
                switch mode {
                case .gauges:
                    GaugesView(connectionManager: connectionManager, pidStore: .shared)
                case .list:
                    GaugeListView(connectionManager: connectionManager)
                 }
            }
        }
        .navigationTitle(titleForMode(mode))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func titleForMode(_ mode: GaugesDisplayMode) -> String {
        switch mode {
        case .gauges: return "Gauges"
        case .list: return "List"
        }
    }
}

#Preview {
    NavigationView {
        GaugesContainerView(connectionManager: .shared)
    }
}
