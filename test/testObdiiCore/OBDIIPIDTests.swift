/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for OBDIIPID Models and Utilities
 *
 * Tests ValueRange operations, PID formatting, unit conversions,
 * color coding, and range calculations.
 */

import XCTest
import SwiftUI
import SwiftOBD2
@testable import obdii

final class OBDIIPIDTests: XCTestCase {

    
    func testValueRangeCreation() {
        let range = ValueRange(min: 0, max: 100)
        XCTAssertEqual(range.min, 0)
        XCTAssertEqual(range.max, 100)
    }
    
    func testValueRangeContains() {
        let range = ValueRange(min: 0, max: 100)
        
        XCTAssertTrue(range.contains(50), "Should contain midpoint")
        XCTAssertTrue(range.contains(0), "Should contain min")
        XCTAssertTrue(range.contains(100), "Should contain max")
        XCTAssertFalse(range.contains(-1), "Should not contain below min")
        XCTAssertFalse(range.contains(101), "Should not contain above max")
    }
    
    func testValueRangeClamp() {
        let range = ValueRange(min: 0, max: 100)
        
        XCTAssertEqual(range.clampedValue(for: 50), 50, "Should not clamp valid value")
        XCTAssertEqual(range.clampedValue(for: -10), 0, "Should clamp to min")
        XCTAssertEqual(range.clampedValue(for: 150), 100, "Should clamp to max")
    }
    
    func testValueRangeNormalizedPosition() {
        let range = ValueRange(min: 0, max: 100)
        
        XCTAssertEqual(range.normalizedPosition(for: 0), 0.0, accuracy: 0.001)
        XCTAssertEqual(range.normalizedPosition(for: 50), 0.5, accuracy: 0.001)
        XCTAssertEqual(range.normalizedPosition(for: 100), 1.0, accuracy: 0.001)
    }
    
    func testValueRangeNormalizedPositionSameMinMax() {
        let range = ValueRange(min: 50, max: 50)
        XCTAssertEqual(range.normalizedPosition(for: 50), 0.0, "Should return 0 when min==max")
    }
    
    func testValueRangeOverlaps() {
        let range1 = ValueRange(min: 0, max: 100)
        let range2 = ValueRange(min: 50, max: 150)
        let range3 = ValueRange(min: 200, max: 300)
        
        XCTAssertTrue(range1.overlaps(range2), "Should overlap")
        XCTAssertFalse(range1.overlaps(range3), "Should not overlap")
    }

    
    func testOBDPIDCreation() {
        let pid = OBDPID(
            id: UUID(),
            enabled: true,
            label: "RPM",
            name: "Engine RPM",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 8000)
        )
        
        XCTAssertEqual(pid.label, "RPM")
        XCTAssertEqual(pid.name, "Engine RPM")
        XCTAssertTrue(pid.enabled)
        XCTAssertEqual(pid.kind, .gauge, "Default kind should be gauge")
    }
    
    func testOBDPIDDefaultName() {
        let pid = OBDPID(
            id: UUID(),
            label: "Test",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 100)
        )
        
        XCTAssertEqual(pid.name, "Test", "Name should default to label")
    }

    
    func testCombinedRange() {
        let pid = OBDPID(
            id: UUID(),
            label: "Test",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 1000),
            warningRange: ValueRange(min: 1000, max: 2000),
            dangerRange: ValueRange(min: 2000, max: 3000)
        )
        
        let combined = pid.combinedRange()
        XCTAssertEqual(combined.min, 0, "Should start at lowest min")
        XCTAssertEqual(combined.max, 3000, "Should end at highest max")
    }
    
    func testCombinedRangeWithNoRanges() {
        let pid = OBDPID(
            id: UUID(),
            label: "Test",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: nil
        )
        
        let combined = pid.combinedRange()
        XCTAssertEqual(combined.min, 0, "Should default to 0")
        XCTAssertEqual(combined.max, 1, "Should default to 1")
    }

    
    @MainActor
    func testColorForValue() {
        let pid = OBDPID(
            id: UUID(),
            label: "Test",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 2000),
            warningRange: ValueRange(min: 2000, max: 4000),
            dangerRange: ValueRange(min: 4000, max: 8000)
        )
        
        XCTAssertEqual(pid.color(for: 1000, unit: .metric), .green, "Typical range should be green")
        XCTAssertEqual(pid.color(for: 3000, unit: .metric), .yellow, "Warning range should be yellow")
        XCTAssertEqual(pid.color(for: 5000, unit: .metric), .red, "Danger range should be red")
        XCTAssertEqual(pid.color(for: 9000, unit: .metric), .gray, "Outside all ranges should be gray")
    }

    
    @MainActor
    func testDisplayRange() {
        let pid = OBDPID(
            id: UUID(),
            label: "RPM",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 8000)
        )
        
        let display = pid.displayRange(for: .metric)
        XCTAssertTrue(display.contains("RPM"), "Should contain unit label")
        XCTAssertTrue(display.contains("0"), "Should contain min value")
        XCTAssertTrue(display.contains("8"), "Should contain max value")
    }

    
    func testOBDPIDEquality() {
        let id = UUID()
        let pid1 = OBDPID(
            id: id,
            label: "RPM",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 8000)
        )
        
        let pid2 = OBDPID(
            id: id,
            label: "RPM",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 8000)
        )
        
        XCTAssertEqual(pid1, pid2, "PIDs with same properties should be equal")
    }
    
    func testOBDPIDHashable() {
        let pid1 = OBDPID(
            id: UUID(),
            label: "RPM",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 8000)
        )
        
        let pid2 = OBDPID(
            id: UUID(),
            label: "Speed",
            pid: .mode1(.speed),
            units: "km/h",
            typicalRange: ValueRange(min: 0, max: 200)
        )
        
        let set = Set([pid1, pid2])
        XCTAssertEqual(set.count, 2, "Different PIDs should be distinct in Set")
    }
}
