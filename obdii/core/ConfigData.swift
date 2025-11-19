import Foundation
import SwiftUI
import Combine
import SwiftOBD2

@MainActor
final class ConfigData: ObservableObject {

    static let shared = ConfigData()

    // MARK: - AppStorage backing

    @AppStorage("wifiHost") var wifiHost: String = "192.168.0.10"
    @AppStorage("wifiPort") var wifiPort: Int = 35000
    @AppStorage("autoConnectToOBD") var autoConnectToOBD: Bool = true

    @AppStorage("connectionType") private var storedConnectionType: String = ConnectionType.bluetooth.rawValue
    @AppStorage("units") private var storedUnitsRaw: String = MeasurementUnit.metric.rawValue

    // MARK: - Published mirrors

    @Published var publishedConnectionType: String
    @Published var units: MeasurementUnit

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {

        //
        // ❗️FIRST: Initialize all stored properties WITHOUT touching self.*
        //
        let initialConnectionRaw = UserDefaults.standard.string(forKey: "connectionType")
            ?? ConnectionType.bluetooth.rawValue

        let initialUnits = MeasurementUnit(
            rawValue: UserDefaults.standard.string(forKey: "units")
                ?? MeasurementUnit.metric.rawValue
        ) ?? .metric

        //
        // ❗️NOW it's safe to assign to @Published properties.
        //
        self.publishedConnectionType = initialConnectionRaw
        self.units = initialUnits

        //
        // ❗️Only now is it legal to access `self` properties.
        //
        superInitAndBind()
    }

    /// Splitting logic out avoids touching `self` before initialization completes.
    private func superInitAndBind() {
        // MARK: - Sync connectionType
        $publishedConnectionType
            .dropFirst()
            .sink { [weak self] newRaw in
                guard let self else { return }
                self.storedConnectionType = newRaw
                ConfigurationService.shared.connectionType =
                    ConnectionType(rawValue: newRaw) ?? .bluetooth
            }
            .store(in: &cancellables)

        // MARK: - Sync units
        $units
            .dropFirst()
            .sink { [weak self] newUnits in
                self?.storedUnitsRaw = newUnits.rawValue
            }
            .store(in: &cancellables)
    }

    // MARK: - API

    var connectionType: ConnectionType {
        get { ConnectionType(rawValue: publishedConnectionType) ?? .bluetooth }
        set { publishedConnectionType = newValue.rawValue }
    }

    func setUnits(_ newUnits: MeasurementUnit) {
        units = newUnits
    }
}
