/**

 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI Settings screen (default tab).
 *
 */

import Observation
import SwiftOBD2
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

struct SettingsView: View {

  @State private var viewModel = SettingsViewModel()

  #if canImport(UIKit)
    @State private var isPresentingShare = false
    @State private var shareItems: [Any] = []
    @State private var isGeneratingLogs = false
    @State private var shareError: String?
  #endif

  private var runningOnMac: Bool {
    #if targetEnvironment(macCatalyst)
      return true
    #else
      return ProcessInfo.processInfo.isiOSAppOnMac
    #endif
  }

  var body: some View {
    @Bindable var viewModel = viewModel

    NavigationStack {
      Form {
        Section {
          NavigationLink("Gauges") {
            PIDToggleListView()
          }
        }
        Section(header: Text("Units")) {
          Picker("Units", selection: $viewModel.units) {
            Text("Metric").tag(MeasurementUnit.metric)
            Text("Imperial").tag(MeasurementUnit.imperial)
          }
          .pickerStyle(.segmented)
        }
        Section(header: Text("Connection")) {
          HStack {
            Text("Status")
            Spacer()
            statusTextView()
          }

          Picker("Type", selection: $viewModel.connectionType) {
            ForEach(ConnectionType.allCases, id: \.self) { type in
              Text(type.rawValue).tag(type)
            }
          }

          Toggle("Automatically Connect", isOn: $viewModel.autoConnectToOBD)

          connectDisconnectButton()
        }
        if viewModel.connectionType == .wifi {
          Section(header: Text("Connection Details")) {
            HStack {
              Text("Host")
              Spacer()
              TextField("e.g., 192.168.0.10", text: $viewModel.wifiHost)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .multilineTextAlignment(.trailing)
            }

            HStack {
              Text("Port")
              Spacer()
              TextField(
                "e.g., 35000",
                value: $viewModel.wifiPort,
                formatter: viewModel.numberFormatter
              )
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
            }
          }
        }
        Section(header: Text("Diagnostics")) {
          #if canImport(UIKit)
            Button {
              if !runningOnMac {
                Task { await shareLogs_iOS() }
              }
            } label: {
              if isGeneratingLogs {
                HStack {
                  ProgressView()
                  Text("Preparing Logs…")
                }
              } else {
                Text("Share Logs")
              }
            }
            .disabled(isGeneratingLogs || runningOnMac)
            .alert(
              "Could not prepare logs",
              isPresented: .constant(shareError != nil)
            ) {
              Button("OK") { shareError = nil }
            } message: {
              Text(shareError ?? "")
            }
          #else
            Button("Share Logs") {}
              .disabled(true)
              .foregroundColor(.secondary)
              .accessibilityHidden(true)
          #endif
        }
        Section(header: Text("About")) {
          HStack {
            Text(aboutDetailString())
              .multilineTextAlignment(.trailing)
          }
        }
      }
      .navigationTitle("Settings")
      #if canImport(UIKit)
        .sheet(isPresented: $isPresentingShare) {
          ShareSheet(activityItems: shareItems)
          .onDisappear { shareItems = [] }
        }
      #endif
    }
  }

  @ViewBuilder
  private func statusTextView() -> some View {
    switch viewModel.connectionState {
    case .disconnected:
      Text("Disconnected").foregroundColor(.gray)

    case .connecting:
      Text("Connecting…").foregroundColor(.orange)

    case .connected:
      Text("Connected").foregroundColor(.green)

    case .failed:
      Text("Failed").foregroundColor(.red)
    }
  }

  @ViewBuilder
  private func connectDisconnectButton() -> some View {
    HStack {
      Spacer()
      Button(action: viewModel.handleConnectionButtonTap) {
        switch viewModel.connectionState {
        case .disconnected, .failed:
          Text("Connect")

        case .connecting:
          HStack {
            Text("Connecting…")
            ProgressView().padding(.leading, 2)
          }

        case .connected:
          Text("Disconnect")
        }
      }
      .disabled(viewModel.isConnectButtonDisabled)
      Spacer()
    }
  }

  #if canImport(UIKit)
    private func sanitizedFilename(from name: String) -> String {
      let allowed = CharacterSet.alphanumerics
        .union(.whitespaces)
        .union(CharacterSet(charactersIn: "-_."))
      let cleanedScalars = name.unicodeScalars.map {
        allowed.contains($0) ? Character($0) : "-"
      }
      let interim = String(cleanedScalars)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return interim.isEmpty ? "App" : interim
    }

    private func shareLogs_iOS() async {
      isGeneratingLogs = true
      defer { isGeneratingLogs = false }

      do {
        // collect last 5 minutes
        let data = try await collectLogs(since: -300)
        let safeBase = sanitizedFilename(from: aboutDetailString())
        let fileName = "\(safeBase)-logs.json"
        let url = try writeToTemporaryFile(data: data, suggestedName: fileName)
        shareItems = [url]
        isPresentingShare = true
      } catch {
        shareError = error.localizedDescription
      }
    }
  #endif

  private func writeToTemporaryFile(data: Data, suggestedName: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedName)
    try data.write(to: url, options: .atomic)
    return url
  }
}

#if canImport(UIKit)
  struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
      UIActivityViewController(
        activityItems: activityItems,
        applicationActivities: nil
      )
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
  }
#endif

#Preview {
  SettingsView()
}
