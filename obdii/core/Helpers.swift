import Foundation
import OSLog
import SwiftOBD2
import UIKit

// MARK: - Log Entry

struct LogEntry: Codable, Sendable {
    let timestamp: Date
    let category: String
    let subsystem: String
    let message: String
}

// MARK: - Symbol and Image Helpers

@inlinable
func symbolImage(named name: String) -> UIImage? {
    UIImage(systemName: name)
}

@inlinable
func imageName(for severity: CodeSeverity) -> String {
    switch severity {
    case .low:      "exclamationmark.circle"
    case .moderate: "exclamationmark.triangle"
    case .high:     "bolt.trianglebadge.exclamationmark"
    case .critical: "xmark.octagon"
    }
}

@inlinable
func severityColor(_ severity: CodeSeverity) -> UIColor {
    switch severity {
    case .low:
        .systemYellow

    case .moderate:
        .systemOrange

    case .high:
        .systemRed

    case .critical:
        UIColor { trait in
            // Use a brighter red in Dark Mode for visibility.
            trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0)
            : UIColor(red: 0.85, green: 0.0,  blue: 0.0,  alpha: 1.0)
        }
    }
}

@inlinable
func tintedSymbol(named name: String, severity: CodeSeverity) -> UIImage? {
    guard let base = UIImage(systemName: name) else { return nil }
    return base.withTintColor(severityColor(severity), renderingMode: .alwaysOriginal)
}

// MARK: - Log Collection

/// Collects log entries from the last N seconds (default: 5 minutes)
/// Only returns logs for our subsystem + selected categories.
///
/// - Parameter since: Negative time interval (e.g., -60 = last 60 seconds)
/// - Returns: JSON Data containing an array of `LogEntry`
func collectLogs(since: TimeInterval = -300) async throws -> Data {

    // Subsystem must match what your app uses in Logger(category:)
    let subsystem = "com.rheosoft.obdii"

    // Categories you consider relevant for export
    let validCategories: Set<String> = [
        "AppInit",
        "Connection",
        "Communication"
    ]

    let store = try OSLogStore(scope: .currentProcessIdentifier)
    let start = store.position(date: Date().addingTimeInterval(since))

    // OSLogEntry is not Sendable → but we immediately map to LogEntry
    let entries = try store.getEntries(at: start)
        .compactMap { $0 as? OSLogEntryLog }
        .filter {
            $0.subsystem == subsystem &&
            validCategories.contains($0.category)
        }

    let mapped: [LogEntry] = entries.map {
        LogEntry(
            timestamp: $0.date,
            category: $0.category,
            subsystem: $0.subsystem,
            message: $0.composedMessage   // Handles privacy masks correctly
        )
    }

    return try JSONEncoder().encode(mapped)
}

// MARK: - About Screen Helper

/// Example: `"MyApp v1.4.2 build:87"`
func aboutDetailString(bundle: Bundle = .main) -> String {
    let displayName =
        bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
        bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
        "App"

    let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    let build   = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"

    return "\(displayName) v\(version) build:\(build)"
}
