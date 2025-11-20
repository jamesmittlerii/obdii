/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * PID data model and library loader
 *
 * Defines the OBDPID struct with metadata (ranges, units, formulas), ValueRange
 * for min/max bounds, and UnitConversion for metric/imperial conversion.
 * Provides formatting, color coding, and display helpers. Loads all PIDs from
 * OBDPIDs.json file via OBDPIDLibrary.loadFromJSON().
 */

//
//  OBDPID Library + Unit Conversion + ValueRange
//  Cleaned + Production-Ready
//

import Foundation
import SwiftOBD2
import SwiftUI

// MARK: - ValueRange

struct ValueRange: Hashable, Codable {
    let min: Double
    let max: Double

    init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }

    @inlinable
    func contains(_ value: Double) -> Bool {
        (min...max).contains(value)
    }

    @inlinable
    func clampedValue(for value: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }

    @inlinable
    func overlaps(_ other: ValueRange) -> Bool {
        !(other.max < min || other.min > max)
    }

    @inlinable
    func normalizedPosition(for value: Double) -> Double {
        guard max != min else { return 0 }
        return (value - min) / (max - min)
    }

    @inlinable
    func converted(from unitLabel: String, to units: MeasurementUnit) -> ValueRange {
        guard let conversion = UnitConversion.fromMetricLabel(unitLabel, to: units) else {
            return self
        }
        return ValueRange(
            min: conversion.convert(min),
            max: conversion.convert(max)
        )
    }
}

// MARK: - UnitConversion

private struct UnitConversion {
    let displayLabel: String
    let convert: (Double) -> Double

    static func fromMetricLabel(_ label: String, to unit: MeasurementUnit) -> UnitConversion? {
        switch label {

        case "°C":
            return unit == .imperial
                ? .init(displayLabel: "°F") { ($0 * 9/5) + 32 }
                : .init(displayLabel: "°C") { $0 }

        case "km/h":
            return unit == .imperial
                ? .init(displayLabel: "mph") { $0 * 0.621371 }
                : .init(displayLabel: "km/h") { $0 }

        case "kPa":
            return unit == .imperial
                ? .init(displayLabel: "psi") { $0 * 0.145038 }
                : .init(displayLabel: "kPa") { $0 }

        case "km":
            return unit == .imperial
                ? .init(displayLabel: "mi") { $0 * 0.621371 }
                : .init(displayLabel: "km") { $0 }

        case "g/s":
            return unit == .imperial
                ? .init(displayLabel: "lb/min") { $0 * 0.132277 }
                : .init(displayLabel: "g/s") { $0 }

        case "L/h":
            return unit == .imperial
                ? .init(displayLabel: "gal/h") { $0 * 0.264172 }
                : .init(displayLabel: "L/h") { $0 }

        // Known "no conversion" units
        case "RPM", "%", "V", "λ", "NA", "Pa", "mA", "° BTDC", "s", "count":
            return .init(displayLabel: label) { $0 }

        default:
            return nil
        }
    }
}

// MARK: - OBDPID

struct OBDPID: Identifiable, Hashable, Codable {

    enum Kind: String, Codable, Hashable {
        case gauge
        case status
    }

    let id: UUID
    var enabled: Bool
    let label: String          // Short name
    let name: String           // Full descriptive name
    let pid: OBDCommand
    let formula: String?
    let units: String?
    let typicalRange: ValueRange?
    let warningRange: ValueRange?
    let dangerRange: ValueRange?
    let notes: String?
    let kind: Kind

    init(
        id: UUID = UUID(),
        enabled: Bool = false,
        label: String,
        name: String? = nil,
        pid: OBDCommand,
        formula: String? = nil,
        units: String,
        typicalRange: ValueRange? = nil,
        warningRange: ValueRange? = nil,
        dangerRange: ValueRange? = nil,
        notes: String? = nil,
        kind: Kind = .gauge
    ) {
        self.id = id
        self.enabled = enabled
        self.label = label
        self.name = name ?? label
        self.pid = pid
        self.formula = formula
        self.units = units
        self.typicalRange = typicalRange
        self.warningRange = warningRange
        self.dangerRange = dangerRange
        self.notes = notes
        self.kind = kind
    }
}

// MARK: - Unit-aware helpers (OBDPID)

extension OBDPID {

    // MARK: Unit Label

    @inlinable
    func unitLabel(for measurementUnit: MeasurementUnit) -> String {
        guard let u = units,
              let conversion = UnitConversion.fromMetricLabel(u, to: measurementUnit)
        else { return units ?? "" }
        return conversion.displayLabel
    }

    
    private func converted(range: ValueRange?, to unit: MeasurementUnit) -> ValueRange? {
        guard let range, let u = units else { return range }
        return range.converted(from: u, to: unit)
    }

    func typicalRange(for unit: MeasurementUnit) -> ValueRange? {
        converted(range: typicalRange, to: unit)
    }
    func warningRange(for unit: MeasurementUnit) -> ValueRange? {
        converted(range: warningRange, to: unit)
    }
    func dangerRange(for unit: MeasurementUnit) -> ValueRange? {
        converted(range: dangerRange, to: unit)
    }

    // MARK: Combined Range

    func combinedRange() -> ValueRange {
        let allRanges = [typicalRange, warningRange, dangerRange].compactMap { $0 }
        guard !allRanges.isEmpty else { return ValueRange(min: 0, max: 1) }

        let minV = allRanges.map(\.min).min()!
        let maxV = allRanges.map(\.max).max()!
        return ValueRange(min: minV, max: maxV)
    }

    // MARK: Display Range

    func displayRange(for unit: MeasurementUnit) -> String {
        guard let units = units else { return "" }

        let converted = combinedRange().converted(from: units, to: unit)
        let label = unitLabel(for: unit)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let digits = preferredFractionDigits(forUnits: label)
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits

        let minStr = formatter.string(from: converted.min as NSNumber) ?? "\(converted.min)"
        let maxStr = formatter.string(from: converted.max as NSNumber) ?? "\(converted.max)"

        return "\(minStr) – \(maxStr) \(label)"
    }

    // MARK: Single Value Formatting

    func formattedValue(
        _ value: Double,
        unit: MeasurementUnit,
        includeUnits: Bool = true
    ) -> String {
        let label = unitLabel(for: unit)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        let digits = preferredFractionDigits(forUnits: label)
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits

        let v = formatter.string(from: value as NSNumber)
            ?? String(format: "%.\(digits)f", value)

        return includeUnits && !label.isEmpty ? "\(v) \(label)" : v
    }

    // MARK: Colors

    func color(for value: Double, unit: MeasurementUnit) -> Color {
        if let r = dangerRange(for: unit), r.contains(value) { return .red }
        if let r = warningRange(for: unit), r.contains(value) { return .yellow }
        if let r = typicalRange(for: unit), r.contains(value) { return .green }
        return .gray
    }

    // MARK: Fraction Digit Rules

    fileprivate func preferredFractionDigits(forUnits units: String) -> Int {
        switch units {
        case "RPM": return 0
        case "°C", "°F": return 0
        case "%": return 0
        case "kPa", "psi": return 0
        case "V": return 2
        case "g/s": return 2
        case "λ": return 2
        case "km/h", "mph": return 0
        case "km", "mi": return 0
        case "L/h": return 1
        case "s", "count": return 0
        default: return 0
        }
    }
}

// MARK: - MeasurementResult Helpers

extension OBDPID {

    func formatted(measurement: MeasurementResult, includeUnits: Bool = true) -> String {

        if measurement.unit is UnitDuration {
            let f = DateComponentsFormatter()
            f.allowedUnits = [.hour, .minute, .second]
            f.unitsStyle = .positional
            f.zeroFormattingBehavior = [.pad]
            return f.string(from: measurement.value) ?? "--:--:--"
        }

        let label = unitLabel(for: measurement.unit)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        let digits = preferredFractionDigits(forUnits: label)
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits

        let v = formatter.string(from: measurement.value as NSNumber)
            ?? String(format: "%.\(digits)f", measurement.value)

        return includeUnits && !label.isEmpty ? "\(v) \(label)" : v
    }

    func unitLabel(for unit: Unit) -> String {
        switch unit {
        case is UnitTemperature: return unit.symbol
        case is UnitSpeed: return unit.symbol
        case is UnitPressure: return unit.symbol
        case is UnitLength: return unit.symbol
        case is UnitElectricPotentialDifference: return "V"
        case is UnitElectricCurrent: return unit.symbol
        case is UnitAngle: return "° BTDC"
        case is UnitDuration: return ""
        case is UnitFrequency: return "Hz"
        default: return unit.symbol
        }
    }
}

// MARK: - Backward-Compatible Convenience

@MainActor
extension OBDPID {
    var displayUnits: String {
        unitLabel(for: ConfigData.shared.units)
    }

    var displayRange: String {
        displayRange(for: ConfigData.shared.units)
    }

    func formattedValue(_ v: Double, includeUnits: Bool = true) -> String {
        formattedValue(v, unit: ConfigData.shared.units, includeUnits: includeUnits)
    }

    func color(for v: Double) -> Color {
        color(for: v, unit: ConfigData.shared.units)
    }
}

// MARK: - PID Library Loader

struct OBDPIDLibrary {

    static func loadFromJSON() -> [OBDPID] {
        guard let url = Bundle.main.url(forResource: "OBDPIDs", withExtension: "json")
        else {
            obdError("OBDPIDs.json missing from bundle.", category: .error)
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([OBDPID].self, from: data)
        } catch {
            obdError("Failed to decode OBDPIDs.json: \(error)", category: .error)
            return []
        }
    }
}
