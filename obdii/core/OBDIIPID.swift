/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
Our library of available PIDs
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */


import Foundation
import SwiftOBD2
import SwiftUI



// Represents a numeric range for a PID value (for scaling, warnings, etc.)
struct ValueRange: Hashable, Codable {
    let min: Double
    let max: Double

    init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }

    

    /// Checks if a value is within the range (inclusive)
    func contains(_ value: Double) -> Bool {
        value >= min && value <= max
    }

    /// Returns a clamped value between min and max
    func clampedValue(for value: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }

    /// Checks if this range overlaps another
    func overlaps(_ other: ValueRange) -> Bool {
        return !(other.max < min || other.min > max)
    }

    /// Returns a normalized 0–1 position within the range
    func normalizedPosition(for value: Double) -> Double {
        guard max != min else { return 0.0 }
        return (value - min) / (max - min)
    }

    /// Convert a metric range to the requested MeasurementUnit for a given unit label.
    /// Only the following conversions are applied:
    /// - Temperature: "°C" <-> "°F"
    /// - Speed: "km/h" <-> "mph"
    /// - Pressure: "kPa" <-> "psi"
    /// - Length: "km" <-> "mi"
    /// All others are returned unchanged.
    func converted(from unitLabel: String, to measurementUnit: MeasurementUnit) -> ValueRange {
        guard let conversion = UnitConversion.fromMetricUnitLabel(unitLabel, to: measurementUnit) else {
            return self
        }
        let newMin = conversion.convert(self.min)
        let newMax = conversion.convert(self.max)
        return ValueRange(min: newMin, max: newMax)
    }
}

//  UnitConversion helper

/// Encapsulates a label mapping and a numeric conversion closure for supported units.
/// We treat stored OBDPID units/ranges as METRIC canonical and convert for presentation.
private struct UnitConversion {
    let displayLabel: String
    let convert: (Double) -> Double

    /// Produce a conversion based on a stored metric label and the requested MeasurementUnit.
    /// Returns nil if no conversion is needed/supported.
    static func fromMetricUnitLabel(_ label: String, to unit: MeasurementUnit) -> UnitConversion? {
        switch label {
        case "°C":
            if unit == .imperial {
                return UnitConversion(displayLabel: "°F") { c in (c * 9.0 / 5.0) + 32.0 }
            } else {
                return UnitConversion(displayLabel: "°C") { $0 }
            }
        case "km/h":
            if unit == .imperial {
                return UnitConversion(displayLabel: "mph") { kmh in kmh * 0.621371 }
            } else {
                return UnitConversion(displayLabel: "km/h") { $0 }
            }
        case "kPa":
            if unit == .imperial {
                return UnitConversion(displayLabel: "psi") { kpa in kpa * 0.145038 }
            } else {
                return UnitConversion(displayLabel: "kPa") { $0 }
            }
        case "km":
            if unit == .imperial {
                return UnitConversion(displayLabel: "mi") { km in km * 0.621371 }
            } else {
                return UnitConversion(displayLabel: "km") { $0 }
            }
        case "g/s":
            if unit == .imperial {
                return UnitConversion(displayLabel: "lb/min") { gs in gs * 0.132277}
            } else {
                return UnitConversion(displayLabel: "g/s") { $0 }
            }
        case "L/h":
            if unit == .imperial {
                return UnitConversion(displayLabel: "gal/h") { l in l * 0.264172}
            } else {
                return UnitConversion(displayLabel: "L/h") { $0 }
            }

        // Units we do not convert here (leave as-is)
        case "RPM", "%", "V", "λ", "NA", "Pa", "mA", "° BTDC", "s", "count":
            return UnitConversion(displayLabel: label) { $0 }

        default:
            // Unknown label → no conversion
            return nil
        }
    }
}

//  OBDPID

/// Represents a single OBD-II Parameter ID (PID) definition.
struct OBDPID: Identifiable, Hashable, Codable {
    enum Kind: String, Codable, Hashable {
        case gauge
        case status
    }

    let id: UUID
    var enabled: Bool
    let label: String          // Short name for compact UI
    let name: String      // Full/original descriptive name
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
        typicalRange: ValueRange,
        warningRange: ValueRange? = nil,
        dangerRange: ValueRange? = nil,
        notes: String? = nil,
        kind: Kind = .gauge
    ) {
        self.id = id
        self.label = label
        self.name = name ?? label
        self.pid = pid
        self.formula = formula
        self.units = units
        self.typicalRange = typicalRange
        self.warningRange = warningRange
        self.dangerRange = dangerRange
        self.notes = notes
        self.enabled = enabled
        self.kind = kind
    }

    //  Unit-aware presentation helpers (based on MeasurementUnit)

    /// Unit label adjusted for the requested measurement system.
    func unitLabel(for measurementUnit: MeasurementUnit) -> String {
        let base = units ?? ""
        guard let conversion = UnitConversion.fromMetricUnitLabel(base, to: measurementUnit) else {
            return base
        }
        return conversion.displayLabel
    }

    /// Convert any stored range (metric canonical) to the requested system using the PID's units label.
    private func converted(range: ValueRange?, for measurementUnit: MeasurementUnit) -> ValueRange? {
        guard let range, let base = units else { return range }
        return range.converted(from: base, to: measurementUnit)
    }

    /// Typical range converted to the requested measurement system.
    func typicalRange(for measurementUnit: MeasurementUnit) -> ValueRange? {
        converted(range: typicalRange, for: measurementUnit)
    }

    /// Warning range converted to the requested measurement system.
    func warningRange(for measurementUnit: MeasurementUnit) -> ValueRange? {
        converted(range: warningRange, for: measurementUnit)
    }

    /// Danger range converted to the requested measurement system.
    func dangerRange(for measurementUnit: MeasurementUnit) -> ValueRange? {
        converted(range: dangerRange, for: measurementUnit)
    }
    
    func displayUnits(for measurementUnit: MeasurementUnit) -> String {
        unitLabel(for: measurementUnit)
    }
    
    func combinedRange() -> ValueRange {
        let metricRanges: [ValueRange] = [typicalRange, warningRange, dangerRange].compactMap { $0 }
        let fallbackTypical = typicalRange ?? ValueRange(min: 0, max: 1)
        let metricMin = metricRanges.map(\.min).min() ?? fallbackTypical.min
        let metricMax = metricRanges.map(\.max).max() ?? fallbackTypical.max
        return ValueRange(min: metricMin, max: metricMax)
    }

    /// Returns a display string for UI, e.g. "600 – 7000 RPM", converted for the requested unit.
    func displayRange(for measurementUnit: MeasurementUnit) -> String {
        guard let baseUnits = units
              //    let metricTypical = combinedRange() //typicalRange
        else { return "" }

        let metricTypical = combinedRange()
        // Convert the typical range and label
        let convertedTypical = metricTypical.converted(from: baseUnits, to: measurementUnit)
        let unitLabel = unitLabel(for: measurementUnit)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let digits = preferredFractionDigits(forUnits: unitLabel)
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits

        let minStr = formatter.string(from: NSNumber(value: convertedTypical.min)) ?? String(format: "%.\(digits)f", convertedTypical.min)
        let maxStr = formatter.string(from: NSNumber(value: convertedTypical.max)) ?? String(format: "%.\(digits)f", convertedTypical.max)

        return "\(minStr) – \(maxStr) \(unitLabel)"
    }

    /// Formats a single value using the same units-aware fraction digit policy as displayRange,
    /// honoring the requested measurement system's unit label.
    func formattedValue(_ value: Double, unit measurementUnit: MeasurementUnit, includeUnits: Bool = true) -> String {
        let unitLabel = unitLabel(for: measurementUnit)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let digits = preferredFractionDigits(forUnits: unitLabel)
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits

        let numberString = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(digits)f", value)
        if includeUnits, !unitLabel.isEmpty {
            return "\(numberString) \(unitLabel)"
        } else {
            return numberString
        }
    }

    //  MeasurementResult-aware presentation helpers (use actual Unit)

    /// Map Foundation.Unit to a concise display label.
    func unitLabel(for foundationUnit: Unit) -> String {
        switch foundationUnit {
        case is UnitDuration:
            return ""
        case is UnitTemperature:
            if foundationUnit == UnitTemperature.celsius { return "°C" }
            if foundationUnit == UnitTemperature.fahrenheit { return "°F" }
            return "°"
        case is UnitSpeed:
            if foundationUnit == UnitSpeed.kilometersPerHour { return "km/h" }
            if foundationUnit == UnitSpeed.milesPerHour { return "mph" }
            return ""
        case is UnitPressure:
            if foundationUnit == UnitPressure.kilopascals { return "kPa" }
            if foundationUnit == UnitPressure.poundsForcePerSquareInch { return "psi" }
            if foundationUnit == UnitPressure.hectopascals { return "hPa" }
            if foundationUnit == UnitPressure.bars { return "bar" }
            return ""
        case is UnitLength:
            if foundationUnit == UnitLength.kilometers { return "km" }
            if foundationUnit == UnitLength.miles { return "mi" }
            return ""
        case is UnitElectricPotentialDifference:
            return "V"
        case is UnitElectricCurrent:
            if foundationUnit == UnitElectricCurrent.milliamperes { return "mA" }
            if foundationUnit == UnitElectricCurrent.amperes { return "A" }
            return "A"
        case is UnitAngle:
            return "° BTDC"
        case is UnitDuration:
            // Not typically used for gauge values; leave blank
            return ""
        case is UnitFrequency:
            return "Hz"
        default:
            // Handle custom Units you defined in decoders.swift
            let symbol = foundationUnit.symbol
            switch symbol {
            case "%": return "%"
            case "g/s": return "g/s"
            case "rpm", "RPM": return "RPM"
            case "Pa": return "Pa"
            case "L/h": return "L/h"
            case "λ": return "λ"
            case "count": return "count"
            case "s": return "s"
            default: return symbol // fallback to whatever Unit.symbol was provided
            }
        }
    }

    /// Formats a MeasurementResult using its own Unit, not the app's MeasurementUnit.
    func formatted(measurement: MeasurementResult, includeUnits: Bool = true) -> String {
        let label = unitLabel(for: measurement.unit)
        
        // do a special case for time based values
        if measurement.unit is UnitDuration {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .positional
            formatter.zeroFormattingBehavior = [.pad]
            return formatter.string(from: measurement.value) ?? "--:--:--"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let digits = preferredFractionDigits(forUnits: label)
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits

        let numberString = formatter.string(from: NSNumber(value: measurement.value)) ?? String(format: "%.\(digits)f", measurement.value)
        if includeUnits, !label.isEmpty {
            return "\(numberString) \(label)"
        } else {
            return numberString
        }
    }

    // Backward-compatible versions that default to the app's configured units

    var displayUnits: String {
        displayUnits(for: ConfigData.shared.units)
    }
    /// Returns a display string for UI, e.g. "600 – 7000 RPM"
    var displayRange: String {
        displayRange(for: ConfigData.shared.units)
    }

    /// Formats a single value using the app's configured units.
    func formattedValue(_ value: Double, includeUnits: Bool = true) -> String {
        formattedValue(value, unit: ConfigData.shared.units, includeUnits: includeUnits)
    }

    /// Unit-aware color evaluation: uses converted ranges for the provided measurement system.
    func color(for value: Double, unit measurementUnit: MeasurementUnit) -> Color {
        if let danger = dangerRange(for: measurementUnit), danger.contains(value) {
            return .red
        }
        if let warn = warningRange(for: measurementUnit), warn.contains(value) {
            return .yellow
        }
        if let typical = typicalRange(for: measurementUnit), typical.contains(value) {
            return .green
        }
        return .gray
    }

    /// Backward-compatible color evaluation using the app's configured units.
    func color(for value: Double) -> Color {
        color(for: value, unit: ConfigData.shared.units)
    }

    /// Pick conventional fraction digits for the given units.
    /// Adjust this mapping as needed for your domain.
    private func preferredFractionDigits(forUnits units: String) -> Int {
        switch units {
        case "RPM":
            return 0
        case "°C", "°F":
            return 0
        case "%":
            return 0
        case "kPa", "psi":
            return 0
        case "V":
            return 2
        case "g/s":
            return 2
        case "λ":
            return 2
        case "km/h", "mph":
            return 0
        case "km", "mi":
            return 0
        case "L/h":
            return 1
        case "s", "count":
            return 0
        default:
            return 0
        }
    }
}



/// Groups a set of standard OBD-II PIDs.
struct OBDPIDLibrary {
    
   
    
    /// Load PIDs from OBDPIDs.json in the app bundle
    static func loadFromJSON() -> [OBDPID] {
        guard let url = Bundle.main.url(forResource: "OBDPIDs", withExtension: "json") else {
            obdError("OBDPIDs.json not found in bundle.", category: .error)
            fatalError()
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let pids = try decoder.decode([OBDPID].self, from: data)
            print("Loaded \(pids.count) PIDs from OBDPIDs.json")
            return pids
        } catch {
            obdError("Failed to load OBDPIDs.json: \(error)",category: .error)
            fatalError()
        }
    }
    
    
}
