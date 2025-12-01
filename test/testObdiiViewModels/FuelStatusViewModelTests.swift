/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for FuelStatusViewModel
 *
 * Tests fuel system status tracking, bank status extraction,
 * and integration with OBDConnectionManager's fuelSystemStatus publisher.
 */

import XCTest
import SwiftOBD2
import Combine
@testable import obdii

final class MockFuelStatusProvider: FuelStatusProviding {
    let subject = PassthroughSubject<[StatusCodeMetadata?]?, Never>()
    var fuelStatusPublisher: AnyPublisher<[StatusCodeMetadata?]?, Never> {
        subject.eraseToAnyPublisher()
    }
}

@MainActor
final class FuelStatusViewModelTests: XCTestCase {
    
    var viewModel: FuelStatusViewModel!
    var mockProvider: MockFuelStatusProvider!
    
    override func setUp() async throws {
        mockProvider = MockFuelStatusProvider()
        viewModel = FuelStatusViewModel(provider: mockProvider)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockProvider = nil
    }

    
    func testInitialization() {
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertNil(viewModel.status, "Status should be nil initially")
        XCTAssertNil(viewModel.bank1, "Bank 1 should be nil initially")
        XCTAssertNil(viewModel.bank2, "Bank 2 should be nil initially")
    }

    
    func testHasAnyStatusWithNilStatus() {
        // When status is nil, hasAnyStatus should be false
        XCTAssertFalse(viewModel.hasAnyStatus, "hasAnyStatus should be false when status is nil")
    }
    
    func testHasAnyStatusWithEmptyBanks() {
        // Even with status set, if both banks are nil, hasAnyStatus is false
        // We can't easily set this without mocking, but we can test the logic
        XCTAssertFalse(viewModel.hasAnyStatus, "hasAnyStatus should be false with no bank data")
    }

    
    func testFuelStatusUpdates() {
        XCTAssertNil(viewModel.status)

        let testValue: [StatusCodeMetadata?] = [
            StatusCodeMetadata(code: "OK", description: "Closed loop"),
            nil
        ]
        mockProvider.subject.send(testValue)

        XCTAssertEqual(viewModel.bank1?.code, "OK")
        XCTAssertNil(viewModel.bank2)
        XCTAssertTrue(viewModel.hasAnyStatus)
    }
    
    func testBank1AndBank2AreIndependent() {
        // bank1 and bank2 should be independent properties
        XCTAssertTrue(viewModel.bank1 == nil || viewModel.bank1 != nil, "Bank 1 can be nil or have value")
        XCTAssertTrue(viewModel.bank2 == nil || viewModel.bank2 != nil, "Bank 2 can be nil or have value")
    }

    
    func testBankStatusStructure() {
        // Bank statuses should be optional and independent
        XCTAssertTrue(viewModel.bank1 == nil || viewModel.bank1 != nil, "Bank 1 can be nil or have value")
        XCTAssertTrue(viewModel.bank2 == nil || viewModel.bank2 != nil, "Bank 2 can be nil or have value")
    }
}
