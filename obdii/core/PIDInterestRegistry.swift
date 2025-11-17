/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
Demand-driven PID interest registry: tracks which OBD commands the UI currently needs.
 
 */

import Foundation
import Combine
import SwiftOBD2

@MainActor
final class PIDInterestRegistry: ObservableObject {
    static let shared = PIDInterestRegistry()

    // Current union set of interested commands
    @Published private(set) var interested: Set<OBDCommand> = []

    // Per-token ownership of commands
    private var byToken: [UUID: Set<OBDCommand>] = [:]

    private init() {}

    func makeToken() -> UUID { UUID() }

    func replace(pids: Set<OBDCommand>, for token: UUID) {
        byToken[token] = pids
        recompute()
    }

    func add(pids: Set<OBDCommand>, for token: UUID) {
        var current = byToken[token] ?? []
        current.formUnion(pids)
        byToken[token] = current
        recompute()
    }

    func remove(pids: Set<OBDCommand>, for token: UUID) {
        guard var current = byToken[token] else { return }
        current.subtract(pids)
        if current.isEmpty {
            byToken.removeValue(forKey: token)
        } else {
            byToken[token] = current
        }
        recompute()
    }

    func clear(token: UUID) {
        byToken.removeValue(forKey: token)
        recompute()
    }

    private func recompute() {
        let union = byToken.values.reduce(into: Set<OBDCommand>()) { acc, next in
            acc.formUnion(next)
        }
        if union != interested {
            // Log the change with human-readable names
            let names = union
                .map { PIDInterestRegistry.displayName(for: $0) }
                .sorted()
                .joined(separator: ", ")
            obdDebug("PIDInterestRegistry: interested set changed to {\(names)}", category: .service)
            interested = union
        }
    }

    // MARK: - Logging helpers

    private static func displayName(for command: OBDCommand) -> String {
        switch command {
        case .mode1(let pid):
            // Try to give a friendly short label when possible
            switch pid {
            case .status: return "Mode01 Status (0101)"
            case .fuelStatus: return "Mode01 Fuel Status (0103)"
            case .rpm: return "Mode01 RPM (010C)"
            case .speed: return "Mode01 Speed (010D)"
            default:
                return "Mode01 \(pid)"
            }
        case .mode3(let m3):
            switch m3 {
            case .GET_DTC: return "Mode03 DTCs"
            }
        case .GMmode22(let gm):
            return "GM Mode22 \(gm)"
        default:
            return String(describing: command)
        }
    }
}
