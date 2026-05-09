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
                Task { await viewModel.prepareLogShare() }
              }
            } label: {
              if viewModel.isGeneratingLogs {
                HStack {
                  ProgressView()
                  Text("Preparing Logs…")
                }
              } else {
                Text("Share Logs")
              }
            }
            .disabled(viewModel.isGeneratingLogs || runningOnMac)
            .alert(
              "Could not prepare logs",
              isPresented: .constant(viewModel.shareErrorMessage != nil)
            ) {
              Button("OK") { viewModel.clearShareError() }
            } message: {
              Text(viewModel.shareErrorMessage ?? "")
            }
          #else
            Button("Share Logs") {
              /* Logs sharing uses UIKit sheet on iOS; other platforms show a disabled stub. */
            }
              .disabled(true)
              .foregroundColor(.secondary)
              .accessibilityHidden(true)
          #endif
        }
        Section(header: Text("About")) {
          HStack {
            Text(viewModel.aboutText)
              .multilineTextAlignment(.trailing)
          }
        }
      }
      .navigationTitle("Settings")
      #if canImport(UIKit)
        .sheet(isPresented: $isPresentingShare) {
          ShareSheet(activityItems: shareItems)
          .onDisappear {
            shareItems = []
            viewModel.clearShareURL()
          }
        }
      #endif
    }
    #if canImport(UIKit)
      .onChange(of: viewModel.shareURL) { _, url in
        guard let url else { return }
        shareItems = [url]
        isPresentingShare = true
      }
    #endif
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
}

#if canImport(UIKit)
  struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
      UIActivityViewController(
        activityItems: activityItems,
        applicationActivities: nil
      )
    }
    func updateUIViewController(_: UIActivityViewController, context _: Context) {
      /* Activity items are fixed at presentation time; no incremental updates. */
    }
  }
#endif

#Preview {
  SettingsView()
}
