/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for GaugeDetailViewModel
 *
 * Tests PID statistics tracking, Combine subscriptions, units change handling,
 * and integration with OBDConnectionManager's pidStats publisher.
 */

import XCTest
import Combine
import SwiftOBD2
@testable import obdii

@MainActor
final class GaugeDetailViewModelTests: XCTestCase {


    final class MockStatsProvider: PIDStatsProviding {
        typealias Stats = OBDConnectionManager.PIDStats
        let subject = CurrentValueSubject<[OBDCommand: Stats], Never>([:])

        var pidStatsPublisher: AnyPublisher<[OBDCommand: Stats], Never> {
            subject.eraseToAnyPublisher()
        }

        func currentStats(for pid: OBDCommand) -> Stats? {
            subject.value[pid]
        }
    }

    final class MockUnitsProvider: UnitsProviding {
        let subject = CurrentValueSubject<MeasurementUnit, Never>(.metric)

        var unitsPublisher: AnyPublisher<MeasurementUnit, Never> {
            subject.eraseToAnyPublisher()
        }
    }


    var viewModel: GaugeDetailViewModel!
    var testPID: OBDPID!
    var statsProvider: MockStatsProvider!
    var unitsProvider: MockUnitsProvider!

    override func setUp() async throws {
        // Create a test PID
        testPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "RPM",
            name: "Engine RPM",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 8000)
        )

        statsProvider = MockStatsProvider()
        unitsProvider = MockUnitsProvider()

        // Seed with no stats initially
        viewModel = GaugeDetailViewModel(
            pid: testPID,
            statsProvider: statsProvider,
            unitsProvider: unitsProvider
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        testPID = nil
        statsProvider = nil
        unitsProvider = nil
    }


    func testInitialization() {
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertEqual(viewModel.pid.id, testPID.id, "Should store the correct PID")
        XCTAssertEqual(viewModel.pid.label, "RPM", "PID label should match")
    }

    func testPIDReference() {
        XCTAssertEqual(viewModel.pid.id, testPID.id, "Should reference the provided PID")
        XCTAssertEqual(viewModel.pid.name, "Engine RPM", "PID name should be accessible")
    }


    func testInitialStatsState() {
        // Stats may be nil initially if no data has been collected
        XCTAssertNil(viewModel.stats, "Stats start nil when provider has no data")
    }

    func testReceivesStatsFromProvider() async throws {
        // Publish a stat for our PID
        let measurement = MeasurementResult(value: 1500.0, unit: Unit(symbol: "rpm"))
        let stat = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: measurement)
        statsProvider.subject.send([.mode1(.rpm): stat])

        // Allow delivery on main
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNotNil(viewModel.stats, "Should receive stats from provider")
        XCTAssertEqual(viewModel.stats?.latest.value, 1500.0, "Latest value should match published stat")
    }

    func testStatsStructure() async throws {
        // Seed a stat
        let measurement = MeasurementResult(value: 2200.0, unit: Unit(symbol: "rpm"))
        let stat = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: measurement)
        statsProvider.subject.send([.mode1(.rpm): stat])

        try await Task.sleep(nanoseconds: 50_000_000)

        if let stats = viewModel.stats {
            XCTAssertGreaterThanOrEqual(stats.sampleCount, 1, "Sample count should be at least 1 after first stat")
            XCTAssertNotNil(stats.latest, "Latest measurement should exist")
            XCTAssertGreaterThanOrEqual(stats.max, stats.min, "Max should be >= min")
        } else {
            XCTFail("Stats should be present after provider emits")
        }
    }


    func testPIDCommand() {
        XCTAssertEqual(viewModel.pid.pid, .mode1(.rpm), "PID command should match")
    }


    func testUnitChangeForcesRefresh() async throws {
        // Seed a stat
        
        // Note: our test PID is rpm; ensure we publish for rpm to match
        let rpmMeas = MeasurementResult(value: 1800.0, unit: Unit(symbol: "rpm"))
        let rpmStat = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: rpmMeas)
        statsProvider.subject.send([.mode1(.rpm): rpmStat])

        try await Task.sleep(nanoseconds: 50_000_000)
        let before = viewModel.stats

        // Trigger unit change
        unitsProvider.subject.send(.imperial)

        try await Task.sleep(nanoseconds: 50_000_000)
        let after = viewModel.stats

        // Since GaugeDetailViewModel refreshes from currentStats(for:), value should persist
        XCTAssertEqual(before?.latest.value, after?.latest.value, "Unit change should refresh but not alter latest value")
    }


    func testStatsDeduplication() async throws {
        // Send an initial stat
        let meas1 = MeasurementResult(value: 2000.0, unit: Unit(symbol: "rpm"))
        let stat1 = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: meas1)
        statsProvider.subject.send([.mode1(.rpm): stat1])
        try await Task.sleep(nanoseconds: 50_000_000)

        // Re-send logically identical stats; should be deduplicated by removeDuplicates
        statsProvider.subject.send([.mode1(.rpm): stat1])
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.stats?.latest.value, 2000.0, "Latest value should remain the same after duplicate")
    }
}
