import Foundation
import Combine
import SwiftOBD2

@MainActor
final class PIDInterestRegistry: ObservableObject {

    static let shared = PIDInterestRegistry()

    /// The union of all PIDs currently requested by all active tokens.
    @Published private(set) var interested: Set<OBDCommand> = []

    /// For each UI owner (identified by UUID), which PIDs it needs.
    private var byToken: [UUID: Set<OBDCommand>] = [:]

    private init() {}

    // MARK: - Token Management

    /// Creates a new owner token. Call `replace(pids:for:)` afterward to register interest.
    func makeToken() -> UUID {
        let token = UUID()
        byToken[token] = []      // Initialize with empty set for safety
        return token
    }

    /// Replaces the entire PID set for a given token.
    func replace(pids: Set<OBDCommand>, for token: UUID) {
        byToken[token] = pids
        recompute()
    }

    /// Clears a token's interest. Safe to call multiple times.
    func clear(token: UUID) {
        byToken[token] = nil
        recompute()
    }

    // MARK: - Internal

    /// Computes the union of all active tokens' PIDs.
    private func recompute() {
        let newUnion = byToken.values.reduce(into: Set<OBDCommand>()) { $0.formUnion($1) }

        guard newUnion != interested else { return }

        interested = newUnion
        logInterestChange(newUnion)
    }

    // MARK: - Logging

    private func logInterestChange(_ set: Set<OBDCommand>) {
        guard !set.isEmpty else {
            obdDebug("PIDInterestRegistry: now empty", category: .service)
            return
        }

        let names = set
            .map(Self.displayName(for:))
            .sorted()
            .joined(separator: ", ")

        obdDebug("PIDInterestRegistry: interested set = { \(names) }", category: .service)
    }

    // MARK: - Display Helpers

    private static func displayName(for cmd: OBDCommand) -> String {
        switch cmd {

        case .mode1(let pid):
            switch pid {
            case .status:      return "Mode01 Status (0101)"
            case .fuelStatus:  return "Mode01 Fuel Status (0103)"
            case .rpm:         return "Mode01 RPM (010C)"
            case .speed:       return "Mode01 Speed (010D)"
            default:           return "Mode01 \(pid)"
            }

        case .mode3(.GET_DTC):
            return "Mode03 DTCs"

        case .GMmode22(let pid):
            return "GM Mode22 \(pid)"

        default:
            return String(describing: cmd)
        }
    }
}
