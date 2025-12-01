import Combine
import CoreBluetooth
/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Main OBD-II connection manager singleton
 *
 * Manages vehicle communication via SwiftOBD2 library, connection lifecycle,
 * and continuous PID data streaming. Integrates with PIDInterestRegistry for
 * demand-driven polling. Publishes connection state, diagnostic codes, fuel
 * status, MIL status, and per-PID statistics. Supports Bluetooth and Wi-Fi adapters.
 */
import Foundation
import SwiftOBD2

@MainActor
final class OBDConnectionManager: ObservableObject {

  enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(Error)

    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
      switch (lhs, rhs) {
      case (.disconnected, .disconnected),
        (.connecting, .connecting),
        (.connected, .connected):
        return true
      case (.failed(let le), .failed(let re)):
        return le.localizedDescription == re.localizedDescription
      default:
        return false
      }
    }

    var isFailed: Bool {
      if case .failed = self { return true }
      return false
    }
  }
  // Whether to query the adapter/vehicle for supported PIDs and filter Mode 01 accordingly.
  private let querySupportedPids = true

  static let shared = OBDConnectionManager()

  // connection status
  @Published var connectionState: ConnectionState = .disconnected
  // Current DTCs (nil = not yet received, [] = loaded but none).
  @Published var troubleCodes: [TroubleCodeMetadata]? = nil
  // FI/O2 fuel system status (nil = not yet received).
  @Published var fuelStatus: [StatusCodeMetadata?]? = nil
  // MIL status (nil = not yet received).
  @Published var MILStatus: Status? = nil
  // Bluetooth peripheral name, or nil for Wi-Fi/Demo/none.
  @Published var connectedPeripheralName: String? = nil
  // Per-PID statistics for live gauge values.
  @Published private(set) var pidStats: [OBDCommand: PIDStats] = [:]

  // our main structure for storing PID stats
  struct PIDStats: Equatable {
    var pid: OBDCommand
    var latest: MeasurementResult
    var min: Double
    var max: Double
    var sampleCount: Int

    init(pid: OBDCommand, measurement: MeasurementResult) {
      self.pid = pid
      self.latest = measurement
      self.min = measurement.value
      self.max = measurement.value
      self.sampleCount = 1
    }

    mutating func update(with measurement: MeasurementResult) {
      let value = measurement.value
      latest = measurement
      if value < min { min = value }
      if value > max { max = value }
      sampleCount &+= 1
    }
  }

  // our gateway to the SwiftOBD library to do the comms
  private var obdService: OBDService
  // General long-lived subscriptions (registry, config, etc.)
  private var managerCancellables = Set<AnyCancellable>()
  // Subscriptions tied to the current OBDService instance.
  private var serviceCancellables = Set<AnyCancellable>()
  // Subscriptions for the continuous updates stream.
  private var streamCancellables = Set<AnyCancellable>()
  // Mode 1 and other supported PIDs reported by the vehicle.
  private var supportedPids: [OBDCommand] = []
  // Last set of PIDs that were actually being streamed.
  private var lastStreamingPIDs: Set<OBDCommand> = []

  private init() {
    obdService = OBDService(
      connectionType: ConfigData.shared.connectionType,
      host: ConfigData.shared.wifiHost,
      port: UInt16(ConfigData.shared.wifiPort)
    )

    bindServiceMirrors()
    bindInterestRegistry()
    bindUnitChanges()
  }
  // Bind OBDService publishers (per-instance).
  private func bindServiceMirrors() {
    serviceCancellables.removeAll()

    // Mirror the connected peripheral name
    obdService.$connectedPeripheral
      .map { $0?.name }
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] name in
        self?.connectedPeripheralName = name
      }
      .store(in: &serviceCancellables)

    // Mirror the OBDService connection state into our own state machine
    obdService.$connectionState
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] serviceState in
        self?.handleServiceConnectionState(serviceState)
      }
      .store(in: &serviceCancellables)
  }
  // Listen for demand-driven interest changes from PIDInterestRegistry.
  private func bindInterestRegistry() {
    PIDInterestRegistry.shared.$interested
      .removeDuplicates()
      .sink { [weak self] interestedSet in
        guard let self else { return }

        // If connected, restart continuous updates with the new interest set
        if connectionState == .connected {
          restartContinuousUpdates(with: interestedSet)
        } else {
          // Not connected: clear stream state so we start clean once connected
          streamCancellables.removeAll()
          lastStreamingPIDs = []
        }
      }
      .store(in: &managerCancellables)
  }
  // Listen for unit changes and reset stats + restart streams as appropriate.
  private func bindUnitChanges() {
    ConfigData.shared.$units
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self else { return }
        let interestedSet = PIDInterestRegistry.shared.interested

        if connectionState == .connected {
          obdInfo(
            "Units changed to \(ConfigData.shared.units.rawValue); restarting continuous updates and resetting stats.",
            category: .service)
          resetAllStats()
          lastStreamingPIDs = []
          restartContinuousUpdates(with: interestedSet)
        } else {
          resetAllStats()
        }
      }
      .store(in: &managerCancellables)
  }

  private func clearForTerminalState() {
    streamCancellables.removeAll()
    lastStreamingPIDs = []
    pidStats.removeAll()
    fuelStatus = nil
    MILStatus = nil
    troubleCodes = nil
    connectedPeripheralName = nil
  }

  private func handleServiceConnectionState(_ serviceState: SwiftOBD2.ConnectionState) {
    switch serviceState {
    case .disconnected:
      clearForTerminalState()
      connectionState = .disconnected
      obdDebug("Mirrored service disconnect to manager state and cleared data.", category: .service)

    case .error:
      clearForTerminalState()
      let err = OBDServiceError.notConnectedToVehicle
      connectionState = .failed(err)
      obdError(
        "Service reported error \(err); mapped to .failed and cleared data.", category: .service)

    case .connecting:
      if connectionState != .connecting {
        connectionState = .connecting
      }

    case .connectedToAdapter, .connectedToVehicle:
      if connectionState != .connected {
        connectionState = .connected
      }
    }
  }
  // Called when host/port/connectionType changes.
  // Disconnects if needed, recreates the OBDService with new settings, and re-binds its publishers.
  func updateConnectionDetails() {
    if connectionState != .disconnected {
      disconnect()
    }

    obdService = OBDService(
      connectionType: ConfigData.shared.connectionType,
      host: ConfigData.shared.wifiHost,
      port: UInt16(ConfigData.shared.wifiPort)
    )

    bindServiceMirrors()
    obdInfo("OBD Service re-initialized with new settings.", category: .service)
  }

  func connect() async {
    guard connectionState == .disconnected || connectionState.isFailed else {
      obdWarning("Connection attempt ignored, already connected or connecting.", category: .service)
      return
    }

    connectionState = .connecting

    do {
      _ = try await obdService.startConnection(
        preferedProtocol: .protocol6,
        timeout: 30,
        querySupportedPIDs: querySupportedPids
      )

      supportedPids = await obdService.getSupportedPIDs()

      connectionState = .connected
      connectedPeripheralName = obdService.connectedPeripheral?.name
      obdInfo("OBD-II connected successfully.", category: .service)

      // Start continuous updates using the current interest set (may be empty)
      startContinuousOBDUpdates(with: PIDInterestRegistry.shared.interested)

    } catch {
      let message = error.localizedDescription
      connectionState = .failed(error)
      connectedPeripheralName = nil
      obdError("OBD-II connection failed: \(message)", category: .service)
    }
  }

  func disconnect() {
    obdService.stopConnection()
    // Do not clear managerCancellables here (those are long-lived)
    streamCancellables.removeAll()
    clearForTerminalState()
    connectionState = .disconnected
    obdInfo("OBD-II disconnected.", category: .service)
  }

  private func resetAllStats() {
    pidStats = pidStats.mapValues { existing in
      var reset = existing
      reset.min = existing.latest.value
      reset.max = existing.latest.value
      reset.sampleCount = 1
      return reset
    }
    obdInfo("All PID stats reset (min/max/sampleCount).", category: .service)
  }

  func stats(for pid: OBDCommand) -> PIDStats? {
    pidStats[pid]
  }

  private func startContinuousOBDUpdates(with interestedPIDs: Set<OBDCommand>) {
    startContinuousOBDUpdatesInternal(with: interestedPIDs)
  }

  private func startContinuousOBDUpdatesInternal(with interestedPIDs: Set<OBDCommand>) {
    var enabledNow = interestedPIDs

    // Filter by supported PIDs if requested
    if querySupportedPids {
      let supportedMode1: Set<OBDCommand> = Set(
        supportedPids.compactMap { cmd in
          if case .mode1(let m) = cmd { return .mode1(m) }
          return nil
        }
      )

      let filtered = Set(
        interestedPIDs.filter { cmd in
          switch cmd {
          case .mode1:
            return supportedMode1.contains(cmd)
          default:
            return true
          }
        })

      let removed = interestedPIDs.subtracting(filtered)
      if !removed.isEmpty {
        obdDebug("Removing unsupported mode1 PIDs: \(removed)", category: .service)
      }

      enabledNow = filtered
    }

    // No commands to monitor
    guard !enabledNow.isEmpty else {
      obdInfo("No interested PIDs to monitor.", category: .service)
      if !lastStreamingPIDs.isEmpty {
        streamCancellables.removeAll()
        lastStreamingPIDs = []
      }
      return
    }

    // If nothing changed, do nothing
    if enabledNow == lastStreamingPIDs {
      obdInfo("Interested PIDs unchanged; not restarting continuous updates.", category: .service)
      return
    }

    // Replace only the stream subscription
    streamCancellables.removeAll()

    let commands = Array(enabledNow)
    lastStreamingPIDs = enabledNow

    obdInfo(
      "Starting continuous updates for \(commands.count) PIDs (demand-driven).", category: .service)

    obdService
      .startContinuousUpdates(commands, unit: ConfigData.shared.units, interval: 1)
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            obdError(
              "Continuous OBD updates failed: \(error.localizedDescription)", category: .service)
          }
        },
        receiveValue: { [weak self] measurements in
          self?.handleUpdateBatch(measurements)
        }
      )
      .store(in: &streamCancellables)
  }

  // deal with a batch of results
  private func handleUpdateBatch(_ batch: [OBDCommand: DecodeResult]) {
    for (command, decode) in batch {
      switch command {

      case .mode1(let pid):
        switch pid {
        // fuel status and MIL status are special cases that we store separately
        case .fuelStatus:
          if let codes = decode.codeResult {
            fuelStatus = codes
          }
        case .status:
          if let status = decode.statusResult {
            MILStatus = status
          }
        // gauges
        default:
          if let measurement = decode.measurementResult {
            let key: OBDCommand = .mode1(pid)
            var stats = pidStats[key] ?? PIDStats(pid: key, measurement: measurement)
            stats.update(with: measurement)
            pidStats[key] = stats
          }
        }

      // GM specific pids
      case .GMmode22:
        if let measurement = decode.measurementResult {
          let key: OBDCommand = command
          var stats = pidStats[key] ?? PIDStats(pid: key, measurement: measurement)
          stats.update(with: measurement)
          pidStats[key] = stats
        }

      // DTC pid
      case .mode3(let m3):
        switch m3 {
        case .GET_DTC:
          if let dtcs = decode.troubleCodesByECU,
            let engine = dtcs[SwiftOBD2.ECUID.engine]
          {
            // Real payload, possibly empty
            troubleCodes = engine
          } else {
            // Loaded, but no codes
            troubleCodes = []
          }
        }

      default:
        continue
      }
    }
  }

  private func restartContinuousUpdates(with interestedPIDs: Set<OBDCommand>) {
    streamCancellables.removeAll()
    lastStreamingPIDs = []
    startContinuousOBDUpdatesInternal(with: interestedPIDs)
  }
}
