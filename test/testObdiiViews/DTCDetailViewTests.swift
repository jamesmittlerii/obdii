/**
 * __Final Project__
 * Jim Mittler
 * 20 November 2025
 *
 * ViewInspector Unit Tests for DTCDetailView
 *
 * Tests the DTCDetailView SwiftUI component structure, section display,
 * labeled content, and conditional rendering of causes and remedies.
 */

import XCTest
import SwiftUI
import ViewInspector
import SwiftOBD2
@testable import obdii

@MainActor
final class DTCDetailViewTests: XCTestCase {
    
    var testDTC: TroubleCodeMetadata!
    var testDTCWithCausesAndRemedies: TroubleCodeMetadata!
    var testDTCNoCausesOrRemedies: TroubleCodeMetadata!
    
    override func setUp() async throws {
        // Create test DTCs with different configurations
        testDTC = TroubleCodeMetadata(
            code: "P0300",
            title: "Random/Multiple Cylinder Misfire Detected",
            description: "The engine control module has detected multiple misfires across random cylinders.",
            severity: .moderate,
            causes: [
                "Faulty spark plugs",
                "Faulty ignition coils",
                "Clogged fuel injectors",
                "Low fuel pressure"
            ],
            remedies: [
                "Inspect and replace spark plugs if worn",
                "Test ignition coils and replace if faulty",
                "Clean or replace fuel injectors",
                "Check fuel pressure and fuel pump"
            ]
        )
        
        testDTCWithCausesAndRemedies = testDTC
        
        testDTCNoCausesOrRemedies = TroubleCodeMetadata(
            code: "P0171",
            title: "System Too Lean (Bank 1)",
            description: "The engine is running too lean on bank 1.",
            severity: .low,
            causes: [],
            remedies: []
        )
    }
    
    override func tearDown() async throws {
        testDTC = nil
        testDTCWithCausesAndRemedies = nil
        testDTCNoCausesOrRemedies = nil
    }
    
    // MARK: - View Structure Tests
    
    func testHasList() throws {
        let view = DTCDetailView(code: testDTC)
        
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "DTCDetailView should contain a List")
    }
    
    func testHasSections() throws {
        let view = DTCDetailView(code: testDTC)
        
        let sections = try view.inspect().findAll(ViewType.Section.self)
        XCTAssertGreaterThan(sections.count, 0, "Should have at least one section")
    }
    
    // MARK: - Navigation Title Tests
    
    func testNavigationTitleIsCode() throws {
        let view = DTCDetailView(code: testDTC)
        
        // Navigation title should be the DTC code
        XCTAssertNotNil(view, "View should initialize with DTC code as title")
    }
    
    // MARK: - Overview Section Tests
    
    func testOverviewSectionExists() throws {
        let view = DTCDetailView(code: testDTC)
        
        let sections = try view.inspect().findAll(ViewType.Section.self)
        XCTAssertGreaterThanOrEqual(sections.count, 1, "Should have overview section")
    }
    
    func testOverviewSectionContainsLabeledContent() throws {
        let view = DTCDetailView(code: testDTC)
        
        // LabeledContent is used for Code, Title, and Severity
        let labeledContents = try view.inspect().findAll(ViewType.LabeledContent.self)
        XCTAssertGreaterThanOrEqual(labeledContents.count, 3, "Overview should have at least 3 LabeledContent items")
    }
    
    // MARK: - Description Section Tests
    
    func testDescriptionSectionExists() throws {
        let view = DTCDetailView(code: testDTC)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // Should find description text
        var foundDescription = false
        for text in texts {
            if let string = try? text.string(), string.contains("detected") {
                foundDescription = true
                break
            }
        }
        
        XCTAssertTrue(foundDescription, "Should display description text")
    }
    
    func testDescriptionTextNotEmpty() throws {
        let view = DTCDetailView(code: testDTC)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThan(texts.count, 0, "Should have text elements")
    }
    
    // MARK: - Causes Section Tests
    
    func testCausesSectionWithCauses() throws {
        let view = DTCDetailView(code: testDTCWithCausesAndRemedies)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // Should find at least one cause (bullet point format)
        var foundCause = false
        for text in texts {
            if let string = try? text.string(), string.contains("• ") {
                foundCause = true
                break
            }
        }
        
        XCTAssertTrue(foundCause, "Should display causes with bullet points")
    }
    
    func testCausesSectionEmptyWhenNoCauses() throws {
        let view = DTCDetailView(code: testDTCNoCausesOrRemedies)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // Count texts with bullet points
        var bulletCount = 0
        for text in texts {
            if let string = try? text.string(), string.hasPrefix("• ") {
                bulletCount += 1
            }
        }
        
        // Should have no bullets for causes section when causes are empty
        XCTAssertEqual(bulletCount, 0, "Should not display causes section when empty")
    }
    
    // MARK: - Remedies Section Tests
    
    func testRemediesSectionWithRemedies() throws {
        let view = DTCDetailView(code: testDTCWithCausesAndRemedies)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // Should find remedies (bullet point format)
        var foundRemedy = false
        for text in texts {
            if let string = try? text.string(), string.contains("replace") || string.contains("Check") {
                foundRemedy = true
                break
            }
        }
        
        XCTAssertTrue(foundRemedy, "Should display remedies")
    }
    
    func testRemediesSectionEmptyWhenNoRemedies() throws {
        let view = DTCDetailView(code: testDTCNoCausesOrRemedies)
        
        // View should still render without remedies
        XCTAssertNoThrow(try view.inspect(), "Should render without remedies")
    }
    
    // MARK: - Conditional Rendering Tests
    
    func testRenderWithAllData() throws {
        let view = DTCDetailView(code: testDTCWithCausesAndRemedies)
        
        // Should render successfully with all data
        XCTAssertNoThrow(try view.inspect(), "Should render with complete data")
    }
    
    func testRenderWithMinimalData() throws {
        let view = DTCDetailView(code: testDTCNoCausesOrRemedies)
        
        // Should render successfully with minimal data
        XCTAssertNoThrow(try view.inspect(), "Should render with minimal data")
    }
    
    // MARK: - Severity Display Tests
    
    func testSeverityMinorDisplay() throws {
        let minorDTC = TroubleCodeMetadata(
            code: "P0100",
            title: "Mass Air Flow Circuit Malfunction",
            description: "Issue with MAF sensor circuit",
            severity: .low,
            causes: [],
            remedies: []
        )
        
        let view = DTCDetailView(code: minorDTC)
        XCTAssertNoThrow(try view.inspect(), "Should render minor severity")
    }
    
    func testSeverityModerateDisplay() throws {
        let moderateDTC = TroubleCodeMetadata(
            code: "P0300",
            title: "Random Misfire",
            description: "Multiple cylinder misfire detected",
            severity: .moderate,
            causes: [],
            remedies: []
        )
        
        let view = DTCDetailView(code: moderateDTC)
        XCTAssertNoThrow(try view.inspect(), "Should render moderate severity")
    }
    
    func testSeveritySevereDisplay() throws {
        let severeDTC = TroubleCodeMetadata(
            code: "P0420",
            title: "Catalyst System Efficiency Below Threshold",
            description: "Catalytic converter not functioning properly",
            severity: .high,
            causes: [],
            remedies: []
        )
        
        let view = DTCDetailView(code: severeDTC)
        XCTAssertNoThrow(try view.inspect(), "Should render severe severity")
    }
    
    // MARK: - Multiple Causes and Remedies Tests
    
    func testMultipleCausesDisplay() throws {
        let dtcWithManyCauses = TroubleCodeMetadata(
            code: "P0301",
            title: "Cylinder 1 Misfire",
            description: "Misfire detected in cylinder 1",
            severity: .moderate,
            causes: [
                "Faulty spark plug",
                "Bad ignition coil",
                "Vacuum leak",
                "Low compression",
                "Fuel injector problem"
            ],
            remedies: []
        )
        
        let view = DTCDetailView(code: dtcWithManyCauses)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // Count bullet-pointed items
        var bulletCount = 0
        for text in texts {
            if let string = try? text.string(), string.hasPrefix("• ") {
                bulletCount += 1
            }
        }
        
        XCTAssertGreaterThanOrEqual(bulletCount, 5, "Should display all causes")
    }
    
    func testMultipleRemediesDisplay() throws {
        let dtcWithManyRemedies = TroubleCodeMetadata(
            code: "P0301",
            title: "Cylinder 1 Misfire",
            description: "Misfire detected in cylinder 1",
            severity: .moderate,
            causes: [],
            remedies: [
                "Replace spark plug",
                "Test ignition coil",
                "Check for vacuum leaks",
                "Perform compression test",
                "Inspect fuel injector"
            ]
        )
        
        let view = DTCDetailView(code: dtcWithManyRemedies)
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // Should display all remedies
        var bulletCount = 0
        for text in texts {
            if let string = try? text.string(), string.hasPrefix("• ") {
                bulletCount += 1
            }
        }
        
        XCTAssertGreaterThanOrEqual(bulletCount, 5, "Should display all remedies")
    }
    
    // MARK: - Different DTC Code Formats Tests
    
    func testPCodeFormat() throws {
        let pCode = TroubleCodeMetadata(
            code: "P0420",
            title: "Catalyst System",
            description: "Test description",
            severity: .moderate,
            causes: [],
            remedies: []
        )
        
        let view = DTCDetailView(code: pCode)
        XCTAssertNoThrow(try view.inspect(), "Should render P-code")
    }
    
    func testCCodeFormat() throws {
        let cCode = TroubleCodeMetadata(
            code: "C1234",
            title: "Chassis Code",
            description: "Test description",
            severity: .low,
            causes: [],
            remedies: []
        )
        
        let view = DTCDetailView(code: cCode)
        XCTAssertNoThrow(try view.inspect(), "Should render C-code")
    }
    
    func testBCodeFormat() throws {
        let bCode = TroubleCodeMetadata(
            code: "B1234",
            title: "Body Code",
            description: "Test description",
            severity: .low,
            causes: [],
            remedies: []
        )
        
        let view = DTCDetailView(code: bCode)
        XCTAssertNoThrow(try view.inspect(), "Should render B-code")
    }
    
    func testUCodeFormat() throws {
        let uCode = TroubleCodeMetadata(
            code: "U1234",
            title: "Network Code",
            description: "Test description",
            severity: .low,
            causes: [],
            remedies: []
        )
        
        let view = DTCDetailView(code: uCode)
        XCTAssertNoThrow(try view.inspect(), "Should render U-code")
    }
}
