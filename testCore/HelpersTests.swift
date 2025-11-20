/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for Helpers
 *
 * Tests utility functions for symbol/image generation, severity color mapping,
 * and app version formatting. Log collection tests are integration-level.
 */

import XCTest
import SwiftOBD2
import UIKit
@testable import obdii

final class HelpersTests: XCTestCase {
    
    // MARK: - Symbol/Image Tests
    
    func testSymbolImageCreation() {
        let image = symbolImage(named: "gear")
        XCTAssertNotNil(image, "Should create system symbol image")
    }
    
    func testSymbolImageWithInvalidName() {
        let image = symbolImage(named: "nonexistent_symbol_12345")
        XCTAssertNil(image, "Should return nil for invalid symbol name")
    }
    
    // MARK: - Severity Image Name Tests
    
    func testImageNameForLowSeverity() {
        let name = imageName(for: .low)
        XCTAssertEqual(name, "exclamationmark.circle", "Low severity should use circle icon")
    }
    
    func testImageNameForModerateSeverity() {
        let name = imageName(for: .moderate)
        XCTAssertEqual(name, "exclamationmark.triangle", "Moderate severity should use triangle icon")
    }
    
    func testImageNameForHighSeverity() {
        let name = imageName(for: .high)
        XCTAssertEqual(name, "bolt.trianglebadge.exclamationmark", "High severity should use bolt icon")
    }
    
    func testImageNameForCriticalSeverity() {
        let name = imageName(for: .critical)
        XCTAssertEqual(name, "xmark.octagon", "Critical severity should use octagon icon")
    }
    
    // MARK: - Severity Color Tests
    
    func testSeverityColorReturnsUIColor() {
        // Disambiguate to the UIKit version by adding type context
        let low: UIColor = severityColor(.low)
        let moderate: UIColor = severityColor(.moderate)
        let high: UIColor = severityColor(.high)
        let critical: UIColor = severityColor(.critical)

        XCTAssertNotNil(low, "Low severity should return a color")
        XCTAssertNotNil(moderate, "Moderate severity should return a color")
        XCTAssertNotNil(high, "High severity should return a color")
        XCTAssertNotNil(critical, "Critical severity should return a color")
    }

    
    func testLogEntryCreation() {
        let entry = LogEntry(
            timestamp: Date(),
            category: "Test",
            subsystem: "com.test",
            message: "Test message"
        )
        
        XCTAssertNotNil(entry, "Should create LogEntry")
        XCTAssertEqual(entry.category, "Test")
        XCTAssertEqual(entry.subsystem, "com.test")
        XCTAssertEqual(entry.message, "Test message")
    }
    
    func testLogEntryCodable() throws {
        let entry = LogEntry(
            timestamp: Date(),
            category: "AppInit",
            subsystem: "com.rheosoft.obdii",
            message: "App started"
        )
        
        // Test encoding
        let data = try JSONEncoder().encode(entry)
        XCTAssertGreaterThan(data.count, 0, "Should encode to JSON")
        
        // Test decoding
        let decoded = try JSONDecoder().decode(LogEntry.self, from: data)
        XCTAssertEqual(decoded.category, entry.category)
        XCTAssertEqual(decoded.subsystem, entry.subsystem)
        XCTAssertEqual(decoded.message, entry.message)
    }
    
    // MARK: - About String Tests
    
    func testAboutDetailString() {
        let aboutString = aboutDetailString()
        
        XCTAssertFalse(aboutString.isEmpty, "About string should not be empty")
        XCTAssertTrue(aboutString.contains("v"), "Should contain version marker")
        XCTAssertTrue(aboutString.contains("build:"), "Should contain build marker")
    }
    
    func testAboutDetailStringFormat() {
        let aboutString = aboutDetailString()
        
        // Should match format: "AppName vX.X.X build:XX"
        let pattern = ".*v.*build:.*"
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.numberOfMatches(
            in: aboutString,
            range: NSRange(aboutString.startIndex..., in: aboutString)
        )
        
        XCTAssertEqual(matches, 1, "Should match expected format")
    }
}
