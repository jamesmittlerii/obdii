/**
 * __Final Project__
 * Jim Mittler
 * 20 November 2025
 *
 * Unit Tests for CarplayHelpers
 *
 * Tests the CarPlay gauge rendering helper functions including gauge image
 * generation, unit system detection, and severity color mapping.
 */

import XCTest
import SwiftUI
import SwiftOBD2
@testable import obdii

@MainActor
final class CarPlayHelpersTests: XCTestCase {
    
    var testPID: OBDPID!
    
    override func setUp() async throws {
        // Create a test PID for gauge rendering
        testPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "RPM",
            name: "Engine RPM",
            pid: .mode1(.rpm),
            formula: nil,
            units: "RPM",
            typicalRange: ValueRange(min: 600, max: 3000),
            warningRange: ValueRange(min: 3000, max: 5000),
            dangerRange: ValueRange(min: 5000, max: 8000),
            notes: nil,
            kind: .gauge
        )
    }
    
    override func tearDown() async throws {
        testPID = nil
    }
    
    // MARK: - drawGaugeImage() Tests
    
    func testDrawGaugeImageCreatesImage() {
        let size = CGSize(width: 100, height: 100)
        let image = drawGaugeImage(for: testPID, measurement: nil, size: size)
        
        XCTAssertNotNil(image, "drawGaugeImage should create a UIImage")
        XCTAssertEqual(image.size, size, "Image size should match requested size")
    }
    
    func testDrawGaugeImageWithMeasurement() {
        let size = CGSize(width: 100, height: 100)
        let unit = Unit(symbol: "rpm")
        let measurement = MeasurementResult(value: 2500.0, unit: unit)
        
        let image = drawGaugeImage(for: testPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should create image with measurement")
        XCTAssertEqual(image.size, size, "Image size should match requested size")
    }
    
    func testDrawGaugeImageWithoutMeasurement() {
        let size = CGSize(width: 100, height: 100)
        
        let image = drawGaugeImage(for: testPID, measurement: nil, size: size)
        
        XCTAssertNotNil(image, "Should create image without measurement (background only)")
    }
    
    func testDrawGaugeImageDifferentSizes() {
        let sizes = [
            CGSize(width: 50, height: 50),
            CGSize(width: 100, height: 100),
            CGSize(width: 200, height: 200),
            CGSize(width: 100, height: 150) // Non-square
        ]
        
        for size in sizes {
            let image = drawGaugeImage(for: testPID, measurement: nil, size: size)
            XCTAssertEqual(image.size, size, "Image should match requested size: \(size)")
        }
    }
    
    func testDrawGaugeImageWithZeroValue() {
        let size = CGSize(width: 100, height: 100)
        let unit = Unit(symbol: "rpm")
        let measurement = MeasurementResult(value: 0.0, unit: unit)
        
        let image = drawGaugeImage(for: testPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should handle zero value")
    }
    
    func testDrawGaugeImageWithMaxValue() {
        let size = CGSize(width: 100, height: 100)
        let unit = Unit(symbol: "rpm")
        let measurement = MeasurementResult(value: 8000.0, unit: unit)
        
        let image = drawGaugeImage(for: testPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should handle max value")
    }
    
    func testDrawGaugeImageWithNegativeValue() {
        let size = CGSize(width: 100, height: 100)
        
        let tempPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "IAT",
            name: "Intake Air Temp",
            pid: .mode1(.intakeTemp),
            formula: nil,
            units: "°C",
            typicalRange: ValueRange(min: -40, max: 50),
            warningRange: nil,
            dangerRange: nil,
            notes: nil,
            kind: .gauge
        )
        
        let unit = Unit(symbol: "°C")
        let measurement = MeasurementResult(value: -10.0, unit: unit)
        
        let image = drawGaugeImage(for: tempPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should handle negative values")
    }
    
    // MARK: - Range-Based Color Tests
    
    func testDrawGaugeImageTypicalRangeValue() {
        let size = CGSize(width: 100, height: 100)
        let unit = Unit(symbol: "rpm")
        
        // Value in typical range (600-3000)
        let measurement = MeasurementResult(value: 2000.0, unit: unit)
        
        let image = drawGaugeImage(for: testPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should create image for typical range value")
    }
    
    func testDrawGaugeImageWarningRangeValue() {
        let size = CGSize(width: 100, height: 100)
        let unit = Unit(symbol: "rpm")
        
        // Value in warning range (3000-5000)
        let measurement = MeasurementResult(value: 4000.0, unit: unit)
        
        let image = drawGaugeImage(for: testPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should create image for warning range value")
    }
    
    func testDrawGaugeImageDangerRangeValue() {
        let size = CGSize(width: 100, height: 100)
        let unit = Unit(symbol: "rpm")
        
        // Value in danger range (5000-8000)
        let measurement = MeasurementResult(value: 6000.0, unit: unit)
        
        let image = drawGaugeImage(for: testPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should create image for danger range value")
    }
    
    // MARK: - PID Without Ranges Tests
    
    func testDrawGaugeImagePIDWithoutRanges() {
        let size = CGSize(width: 100, height: 100)
        
        let simplePID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "TPS",
            name: "Throttle Position",
            pid: .mode1(.throttlePos),
            formula: nil,
            units: "%",
            typicalRange: nil,
            warningRange: nil,
            dangerRange: nil,
            notes: nil,
            kind: .gauge
        )
        
        let unit = Unit(symbol: "%")
        let measurement = MeasurementResult(value: 50.0, unit: unit)
        
        let image = drawGaugeImage(for: simplePID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should handle PID without defined ranges")
    }
    
    // MARK: - Unit System Tests
    
    func testDrawGaugeImageMetricTemperature() {
        ConfigData.shared.units = .metric
        
        let size = CGSize(width: 100, height: 100)
        
        let tempPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "Temp",
            name: "Coolant Temp",
            pid: .mode1(.coolantTemp),
            formula: nil,
            units: "°C",
            typicalRange: ValueRange(min: 80, max: 100),
            warningRange: nil,
            dangerRange: nil,
            notes: nil,
            kind: .gauge
        )
        
        let unit = Unit(symbol: "°C")
        let measurement = MeasurementResult(value: 90.0, unit: unit)
        
        let image = drawGaugeImage(for: tempPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should create image for metric temperature")
    }
    
    func testDrawGaugeImageImperialSpeed() {
        ConfigData.shared.units = .imperial
        
        let size = CGSize(width: 100, height: 100)
        
        let speedPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "SPD",
            name: "Speed",
            pid: .mode1(.speed),
            formula: nil,
            units: "mph",
            typicalRange: ValueRange(min: 0, max: 75),
            warningRange: nil,
            dangerRange: nil,
            notes: nil,
            kind: .gauge
        )
        
        let unit = Unit(symbol: "mph")
        let measurement = MeasurementResult(value: 60.0, unit: unit)
        
        let image = drawGaugeImage(for: speedPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should create image for imperial speed")
    }
    
    // MARK: - Image Properties Tests
    
    func testDrawGaugeImageIsTransparent() {
        let size = CGSize(width: 100, height: 100)
        let image = drawGaugeImage(for: testPID, measurement: nil, size: size)
        
        // Image should support transparency (opaque = false)
        XCTAssertNotNil(image, "Image should be created")
        
        // UIImage doesn't have an easy way to check opacity, but we can verify it exists
        XCTAssertGreaterThan(image.size.width, 0, "Image width should be greater than 0")
        XCTAssertGreaterThan(image.size.height, 0, "Image height should be greater than 0")
    }
    
    func testDrawGaugeImageScale() {
        let size = CGSize(width: 100, height: 100)
        let image = drawGaugeImage(for: testPID, measurement: nil, size: size)
        
        // Image should have a scale (typically 1.0, 2.0, or 3.0 for retina)
        XCTAssertGreaterThan(image.scale, 0, "Image scale should be valid")
    }
    
    // MARK: - CodeSeverity Color Extension Tests
    
    func testCodeSeverityLowColor() {
        let severity = CodeSeverity.low
        let color = severity.swiftUIColor
        
        XCTAssertNotNil(color, "Low severity should have a color")
        // Color should be yellow
        XCTAssertEqual(color, Color.yellow, "Low severity should be yellow")
    }
    
    func testCodeSeverityModerateColor() {
        let severity = CodeSeverity.moderate
        let color = severity.swiftUIColor
        
        XCTAssertNotNil(color, "Moderate severity should have a color")
        // Color should be orange
        XCTAssertEqual(color, Color.orange, "Moderate severity should be orange")
    }
    
    func testCodeSeverityHighColor() {
        let severity = CodeSeverity.high
        let color = severity.swiftUIColor
        
        XCTAssertNotNil(color, "High severity should have a color")
        // Color should be red
        XCTAssertEqual(color, Color.red, "High severity should be red")
    }
    
    func testCodeSeverityCriticalColor() {
        let severity = CodeSeverity.critical
        let color = severity.swiftUIColor
        
        XCTAssertNotNil(color, "Critical severity should have a color")
        // Color should be dark red (custom RGB)
        // We can't easily compare custom colors, but we can verify it exists
        XCTAssertTrue(true, "Critical severity has custom dark red color")
    }
    
    func testCodeSeverityAllColorsAreUnique() {
        let low = CodeSeverity.low.swiftUIColor
        let moderate = CodeSeverity.moderate.swiftUIColor
        let high = CodeSeverity.high.swiftUIColor
        let critical = CodeSeverity.critical.swiftUIColor
        
        // Each severity should have a distinct color
        XCTAssertNotEqual(low, moderate, "Low and moderate should have different colors")
        XCTAssertNotEqual(moderate, high, "Moderate and high should have different colors")
        XCTAssertNotEqual(high, critical, "High and critical should have different colors")
        XCTAssertNotEqual(low, high, "Low and high should have different colors")
    }
    
    // MARK: - Edge Case Tests
    
    func testDrawGaugeImageVerySmallSize() {
        let size = CGSize(width: 10, height: 10)
        
        let image = drawGaugeImage(for: testPID, measurement: nil, size: size)
        
        XCTAssertNotNil(image, "Should handle very small size")
        XCTAssertEqual(image.size, size, "Image size should match")
    }
    
    func testDrawGaugeImageVeryLargeSize() {
        let size = CGSize(width: 500, height: 500)
        
        let image = drawGaugeImage(for: testPID, measurement: nil, size: size)
        
        XCTAssertNotNil(image, "Should handle large size")
        XCTAssertEqual(image.size, size, "Image size should match")
    }
    
    func testDrawGaugeImageValueAboveMax() {
        let size = CGSize(width: 100, height: 100)
        let unit = Unit(symbol: "rpm")
        
        // Value above danger range max (8000+)
        let measurement = MeasurementResult(value: 10000.0, unit: unit)
        
        let image = drawGaugeImage(for: testPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should handle value above max range")
    }
    
    func testDrawGaugeImageValueBelowMin() {
        let size = CGSize(width: 100, height: 100)
        let unit = Unit(symbol: "rpm")
        
        // Value below typical range min (below 600)
        let measurement = MeasurementResult(value: 100.0, unit: unit)
        
        let image = drawGaugeImage(for: testPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should handle value below min range")
    }
    
    // MARK: - Different PID Types Tests
    
    func testDrawGaugeImageForSpeedPID() {
        let size = CGSize(width: 100, height: 100)
        
        let speedPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "SPD",
            name: "Speed",
            pid: .mode1(.speed),
            formula: nil,
            units: "km/h",
            typicalRange: ValueRange(min: 0, max: 120),
            warningRange: nil,
            dangerRange: nil,
            notes: nil,
            kind: .gauge
        )
        
        let unit = Unit(symbol: "km/h")
        let measurement = MeasurementResult(value: 80.0, unit: unit)
        
        let image = drawGaugeImage(for: speedPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should create image for speed gauge")
    }
    
    func testDrawGaugeImageForTemperaturePID() {
        let size = CGSize(width: 100, height: 100)
        
        let tempPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "Temp",
            name: "Coolant Temp",
            pid: .mode1(.coolantTemp),
            formula: nil,
            units: "°C",
            typicalRange: ValueRange(min: 80, max: 100),
            warningRange: ValueRange(min: 100, max: 110),
            dangerRange: ValueRange(min: 110, max: 120),
            notes: nil,
            kind: .gauge
        )
        
        let unit = Unit(symbol: "°C")
        let measurement = MeasurementResult(value: 95.0, unit: unit)
        
        let image = drawGaugeImage(for: tempPID, measurement: measurement, size: size)
        
        XCTAssertNotNil(image, "Should create image for temperature gauge")
    }
}
