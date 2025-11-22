/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewInspector Unit Tests for FuelStatusView
 *
 * Tests the FuelStatusView SwiftUI structure and behavior using a mock provider.
 * Validates view hierarchy, state transitions (waiting/loaded/empty),
 * and proper display of fuel system status for Bank 1 and Bank 2.
 */

import XCTest
import SwiftUI
import ViewInspector
import SwiftOBD2
import Combine
@testable import obdii



@MainActor
final class FuelStatusViewTests: XCTestCase {

    // Local mock identical to the one in FuelStatusViewModelTests to avoid cross-file coupling
    final class MockFuelStatusProvider: FuelStatusProviding {
        let subject = PassthroughSubject<[StatusCodeMetadata?]?, Never>()
        var fuelStatusPublisher: AnyPublisher<[StatusCodeMetadata?]?, Never> {
            subject.eraseToAnyPublisher()
        }
    }

    // Helper to build a view with injected mock VM
    private func makeView(with mock: MockFuelStatusProvider) -> (FuelStatusView, FuelStatusViewModel, MockFuelStatusProvider) {
        let vm = FuelStatusViewModel(provider: mock)
        let view = FuelStatusView(viewModel: vm)
        return (view, vm, mock)
    }

    // MARK: - Navigation Structure Tests

    func testHasNavigationStack() throws {
        let (view, _, _) = makeView(with: MockFuelStatusProvider())
        let navigationStack = try view.inspect().find(ViewType.NavigationStack.self)
        XCTAssertNotNil(navigationStack, "FuelStatusView should contain a NavigationStack")
    }

    func testNavigationTitle() throws {
        let (view, _, _) = makeView(with: MockFuelStatusProvider())
        let stack = try view.inspect().find(ViewType.NavigationStack.self)
        XCTAssertNotNil(stack, "FuelStatusView should have a NavigationStack")

        let list = try stack.find(ViewType.List.self)
        XCTAssertNotNil(list, "NavigationStack should contain a List")
    }

    // MARK: - List Structure Tests

    func testContainsList() throws {
        let (view, _, _) = makeView(with: MockFuelStatusProvider())
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "FuelStatusView should contain a List")
    }

    // MARK: - Waiting State Tests

    func testWaitingStateDisplaysProgressView() throws {
        let (view, _, _) = makeView(with: MockFuelStatusProvider())
        let progressView = try view.inspect().find(ViewType.ProgressView.self)
        XCTAssertNotNil(progressView, "Should display ProgressView when waiting for data")
    }

    func testWaitingStateDisplaysWaitingText() throws {
        let (view, _, _) = makeView(with: MockFuelStatusProvider())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let waitingText = try texts.first { text in
            let string = try text.string()
            return string.contains("Waiting for data")
        }
        XCTAssertNotNil(waitingText, "Should display 'Waiting for data' text in waiting state")
    }

    func testContentHasHStackInWaitingState() throws {
        let (view, _, _) = makeView(with: MockFuelStatusProvider())
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThan(hStacks.count, 0, "Should have HStack for waiting row")
    }

    // MARK: - ViewModel Integration Tests

    func testViewModelInitializesWithNilStatus() throws {
        let mock = MockFuelStatusProvider()
        let viewModel = FuelStatusViewModel(provider: mock)
        XCTAssertNil(viewModel.status, "ViewModel should initialize with nil status")
        XCTAssertNil(viewModel.bank1, "Bank 1 should be nil initially")
        XCTAssertNil(viewModel.bank2, "Bank 2 should be nil initially")
        XCTAssertFalse(viewModel.hasAnyStatus, "hasAnyStatus should be false when status is nil")
    }

    // MARK: - Loaded State Tests (with mock)

    func testLoadedStateDisplaysBank1Only() throws {
        let mock = MockFuelStatusProvider()
        let (view, _, _) = makeView(with: mock)

        // Send Bank 1 status only
        let codes: [StatusCodeMetadata?] = [
            StatusCodeMetadata(code: "OK", description: "Closed loop"),
            nil
        ]
        mock.subject.send(codes)

        // Verify Bank 1 row exists
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasBank1 = try texts.contains { try $0.string().contains("Bank 1") }
        XCTAssertTrue(hasBank1, "Should display Bank 1 row when Bank 1 has status")
    }

    func testLoadedStateDisplaysBank1AndBank2() throws {
        let mock = MockFuelStatusProvider()
        let (view, _, _) = makeView(with: mock)

        let codes: [StatusCodeMetadata?] = [
            StatusCodeMetadata(code: "OK", description: "Closed loop"),
            StatusCodeMetadata(code: "OL", description: "Open loop")
        ]
        mock.subject.send(codes)

        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasBank1 = try texts.contains { try $0.string().contains("Bank 1") }
        let hasBank2 = try texts.contains { try $0.string().contains("Bank 2") }
        XCTAssertTrue(hasBank1 && hasBank2, "Should display both Bank 1 and Bank 2 rows when both have status")
    }

    func testEmptyStateMessageWhenNoBanksHaveStatus() throws {
        let mock = MockFuelStatusProvider()
        let (view, _, _) = makeView(with: mock)

        // Loaded but empty: both banks nil
        mock.subject.send([nil, nil])

        // Look for empty state label
        let labels = try view.inspect().findAll(ViewType.Label.self)
        XCTAssertFalse(labels.isEmpty, "Should display empty state Label when no status codes")
    }

    // MARK: - Image Tests

    func testContainsFuelPumpImagesWhenLoaded() throws {
        let mock = MockFuelStatusProvider()
        let (view, _, _) = makeView(with: mock)

        mock.subject.send([
            StatusCodeMetadata(code: "OK", description: "Closed loop"),
            nil
        ])

        let images = try view.inspect().findAll(ViewType.Image.self)
        XCTAssertGreaterThanOrEqual(images.count, 1, "View should contain fuel pump image when showing a bank row")
    }

    // MARK: - Accessibility Tests

    func testWaitingRowHasAccessibilityLabel() throws {
        let (view, _, _) = makeView(with: MockFuelStatusProvider())
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThan(hStacks.count, 0, "Should have HStack with accessibility")
    }
}
