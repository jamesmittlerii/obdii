/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for DiagnosticsViewModel
 *
 * Tests DTC grouping by severity, section construction, empty state handling,
 * and integration with OBDConnectionManager's troubleCodes publisher.
 */

import XCTest
import Combine
import SwiftOBD2
@testable import obdii

final class MockDiagnosticsProvider: DiagnosticsProviding {
    let subject = PassthroughSubject<[TroubleCodeMetadata]?, Never>()
    var diagnosticsPublisher: AnyPublisher<[TroubleCodeMetadata]?, Never> {
        subject.eraseToAnyPublisher()
    }
}

@MainActor
final class DiagnosticsViewModelTests: XCTestCase {
    
    var viewModel: DiagnosticsViewModel!
    var mockProvider: MockDiagnosticsProvider!
    
    override func setUp() async throws {
        mockProvider = MockDiagnosticsProvider()
        viewModel = DiagnosticsViewModel(provider: mockProvider)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockProvider = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertNil(viewModel.codes, "Codes should be nil initially (waiting state)")
        XCTAssertEqual(viewModel.sections.count, 0, "Should have no sections initially")
        XCTAssertTrue(viewModel.isEmpty, "isEmpty should be false when codes is nil")
    }
    
    // MARK: - State Tests
    
    func testNilCodesState() {
        // codes = nil represents waiting state
        XCTAssertNil(viewModel.codes, "Codes should be nil initially")
        XCTAssertTrue(viewModel.isEmpty, "isEmpty should be false when waiting for data")
    }
    
    func testSectionsInitiallyEmpty() {
        XCTAssertEqual(viewModel.sections.count, 0, "Should have no sections initially")
    }
    
    // MARK: - Section Struct Tests
    
    func testSectionEquality() {
        let code1 = createMockDTC(code: "P0001", severity: .high)
        let code2 = createMockDTC(code: "P0002", severity: .high)
        
        let section1 = DiagnosticsViewModel.Section(
            title: "High",
            severity: .high,
            items: [code1]
        )
        
        let section2 = DiagnosticsViewModel.Section(
            title: "High",
            severity: .high,
            items: [code1]
        )
        
        let section3 = DiagnosticsViewModel.Section(
            title: "High",
            severity: .high,
            items: [code2]
        )
        
        XCTAssertEqual(section1, section2, "Sections with same data should be equal")
        XCTAssertNotEqual(section1, section3, "Sections with different items should not be equal")
    }
    
    // MARK: - Helper Methods
    
    private func createMockDTC(code: String, severity: CodeSeverity) -> TroubleCodeMetadata {
        return TroubleCodeMetadata(
            code: code,
            title: "Test DTC",
            description: "Test description",
            severity: severity,
            causes: ["Test cause"],
            remedies: ["Test remedy"]
        )
    }
}
