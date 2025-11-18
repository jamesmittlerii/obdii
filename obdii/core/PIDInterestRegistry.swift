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

   
    // Enqueue the clear on the main queue so it runs after current work.
    func clear(token: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.byToken.removeValue(forKey: token)
            self.recompute()
        }
    }

    private func recompute() {
        let union = byToken.values.reduce(into: Set<OBDCommand>()) { acc, next in
            acc.formUnion(next)
        }
        if union != interested {
            let names = union
                .map { PIDInterestRegistry.displayName(for: $0) }
                .sorted()
                .joined(separator: ", ")
            obdDebug("PIDInterestRegistry: interested set changed to {\(names)}", category: .service)
            interested = union
        }
    }

    private static func displayName(for command: OBDCommand) -> String {
        switch command {
        case .mode1(let pid):
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
