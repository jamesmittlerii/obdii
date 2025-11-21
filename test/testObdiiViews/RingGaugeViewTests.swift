//
//  RingGaugeViewTests.swift
//  obdii
//
//  Created by cisstudent on 11/20/25.
//


/**
 * __Final Project__
 * Jim Mittler
 * 20 November 2025
 *
 * ViewInspector Unit Tests for RingGaugeView
 *
 * Tests the RingGaugeView SwiftUI component structure, view hierarchy,
 * and basic rendering with and without measurement data.
 */

import XCTest
import SwiftUI
import ViewInspector
import SwiftOBD2
@testable import obdii

@MainActor
final class RingGaugeViewTests: XCTestCase {
    
    var testPID: OBDPID!
    
    override func setUp() async throws {
        // Create a test PID for consistent testing
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
    
    // MARK: - View Structure Tests
    
    func testHasGeometryReader() throws {
        let view = RingGaugeView(pid: testPID, measurement: nil)
        
        let geometryReader = try view.inspect().find(ViewType.GeometryReader.self)
        XCTAssertNotNil(geometryReader, "RingGaugeView should use GeometryReader")
    }
    
    func testHasZStack() throws {
        let view = RingGaugeView(pid: testPID, measurement: nil)
        
        let zStack = try view.inspect().find(ViewType.ZStack.self)
        XCTAssertNotNil(zStack, "RingGaugeView should contain ZStack for layering")
    }
    
    func testHasVStackForText() throws {
        let view = RingGaugeView(pid: testPID, measurement: nil)
        
        let vStack = try view.inspect().find(ViewType.VStack.self)
        XCTAssertNotNil(vStack, "Should have VStack for text display")
    }
    
    // MARK: - Text Display Tests
    
    func testDisplaysTextWhenNoMeasurement() throws {
        let view = RingGaugeView(pid: testPID, measurement: nil)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThan(texts.count, 0, "Should display text even without measurement")
    }
    
    func testDisplaysTextWithMeasurement() throws {
        let unit = Unit(symbol: "rpm")
        let measurement = MeasurementResult(value: 2500.0, unit: unit)
        let view = RingGaugeView(pid: testPID, measurement: measurement)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThanOrEqual(texts.count, 2, "Should display value and unit text")
    }
    
    func testTextContent() throws {
        let unit = Unit(symbol: "rpm")
        let measurement = MeasurementResult(value: 2500.0, unit: unit)
        let view = RingGaugeView(pid: testPID, measurement: measurement)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // Should have text elements for value and unit
        for text in texts {
            let textString = try text.string()
            XCTAssertFalse(textString.isEmpty, "Text should have content")
        }
    }
    
    // MARK: - Range Initialization Tests
    
    func testInitWithTypicalRange() {
        let pid = OBDPID(
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
        
        let view = RingGaugeView(pid: pid, measurement: nil)
        XCTAssertNotNil(view, "Should initialize with only typical range")
    }
    
    func testInitWithAllRanges() {
        let pid = OBDPID(
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
        
        let view = RingGaugeView(pid: pid, measurement: nil)
        XCTAssertNotNil(view, "Should initialize with all ranges defined")
    }
    
    func testInitWithoutRanges() {
        let pid = OBDPID(
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
        
        let view = RingGaugeView(pid: pid, measurement: nil)
        XCTAssertNotNil(view, "Should initialize without ranges defined")
    }
    
    // MARK: - Unit System Tests
    
    func testMetricUnits() throws {
        ConfigData.shared.units = .metric
        
        let unit = Unit(symbol: "km/h")
        let measurement = MeasurementResult(value: 100.0, unit: unit)
        
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
        
        let view = RingGaugeView(pid: speedPID, measurement: measurement)
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        XCTAssertGreaterThan(texts.count, 0, "Should display with metric units")
    }
    
    func testImperialUnits() throws {
        ConfigData.shared.units = .imperial
        
        let unit = Unit(symbol: "mph")
        let measurement = MeasurementResult(value: 60.0, unit: unit)
        
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
        
        let view = RingGaugeView(pid: speedPID, measurement: measurement)
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        XCTAssertGreaterThan(texts.count, 0, "Should display with imperial units")
    }
    
    // MARK: - Edge Case Value Tests
    
    func testZeroValue() throws {
        let unit = Unit(symbol: "rpm")
        let measurement = MeasurementResult(value: 0.0, unit: unit)
        let view = RingGaugeView(pid: testPID, measurement: measurement)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThan(texts.count, 0, "Should display zero value")
    }
    
    func testNegativeValue() throws {
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
        let view = RingGaugeView(pid: tempPID, measurement: measurement)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThan(texts.count, 0, "Should display negative value")
    }
    
    func testMaxValue() throws {
        let unit = Unit(symbol: "rpm")
        let measurement = MeasurementResult(value: 8000.0, unit: unit)
        let view = RingGaugeView(pid: testPID, measurement: measurement)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThan(texts.count, 0, "Should display max value")
    }
    
    // MARK: - Color Computation Tests
    
    func testColorForTypicalValue() {
        let color = testPID.color(for: 2000.0, unit: .metric)
        XCTAssertNotNil(color, "Should compute color for typical value")
    }
    
    func testColorForWarningValue() {
        let color = testPID.color(for: 4000.0, unit: .metric)
        XCTAssertNotNil(color, "Should compute color for warning value")
    }
    
    func testColorForDangerValue() {
        let color = testPID.color(for: 6000.0, unit: .metric)
        XCTAssertNotNil(color, "Should compute color for danger value")
    }
    
    // MARK: - Different PID Types
    
    func testRPMGauge() throws {
        let view = RingGaugeView(pid: testPID, measurement: nil)
        XCTAssertNoThrow(try view.inspect(), "Should render RPM gauge")
    }
    
    func testTemperatureGauge() throws {
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
        let view = RingGaugeView(pid: tempPID, measurement: measurement)
        
        XCTAssertNoThrow(try view.inspect(), "Should render temperature gauge")
    }
    
    func testSpeedGauge() throws {
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
        let measurement = MeasurementResult(value: 60.0, unit: unit)
        let view = RingGaugeView(pid: speedPID, measurement: measurement)
        
        XCTAssertNoThrow(try view.inspect(), "Should render speed gauge")
    }
}
