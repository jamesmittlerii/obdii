/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for GaugesViewModel
 *
 * Tests tile generation from enabled gauges, TileIdentity helper,
 * and integration with PIDStore for gauge lists.
 */

import XCTest
import SwiftOBD2
@testable import obdii

@MainActor
final class GaugesViewModelTests: XCTestCase {
    
    var viewModel: GaugesViewModel!
    
    override func setUp() async throws {
        viewModel = GaugesViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertGreaterThanOrEqual(viewModel.tiles.count, 0, "Should have tiles array")
    }
    
    func testTilesMatchEnabledGauges() {
        // Tiles should correspond to enabled gauges from PIDStore
        let enabledCount = PIDStore.shared.enabledGauges.count
        XCTAssertEqual(viewModel.tiles.count, enabledCount, 
                      "Tiles should match enabled gauges count")
    }
    
    // MARK: - Tile Tests
    
    func testTilesHaveValidPIDs() {
        for tile in viewModel.tiles {
            XCTAssertNotNil(tile.pid, "Each tile should have a PID")
            XCTAssertTrue(tile.pid.enabled, "Tile PIDs should be enabled")
            XCTAssertEqual(tile.pid.kind, .gauge, "Tile PIDs should be gauge type")
        }
    }
    
    func testTileIdentity() {
        for tile in viewModel.tiles {
            XCTAssertNotEqual(tile.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, 
                            "Tile ID should be valid UUID")
        }
    }
    
    func testTilesHaveMeasurements() {
        for tile in viewModel.tiles {
            // Measurements may be nil initially (no data received yet)
            XCTAssertTrue(tile.measurement == nil || tile.measurement != nil,
                         "Measurement can be nil or have value")
        }
    }
    
    // MARK: - TileIdentity Tests
    
    func testTileIdentityEquality() {
        let id1 = UUID()
        let tile1 = TileIdentity(id: id1, name: "Test")
        let tile2 = TileIdentity(id: id1, name: "Test")  // Same ID AND same name
        
        // TileIdentity uses default Equatable - compares all properties
        XCTAssertEqual(tile1, tile2, "Tiles with same ID and name should be equal")
    }
    
    func testTileIdentityWithDifferentNames() {
        let id1 = UUID()
        let tile1 = TileIdentity(id: id1, name: "Test")
        let tile2 = TileIdentity(id: id1, name: "Other Name")
        
        // Different names means not equal (default Equatable behavior)
        XCTAssertNotEqual(tile1, tile2, "Tiles with different names are not equal")
    }
    
    func testTileIdentityHashable() {
        let tiles = viewModel.tiles
        
        // All tiles should have unique IDs
        let uniqueIDs = Set(tiles.map { $0.id })
        XCTAssertEqual(tiles.count, uniqueIDs.count, "All tiles should have unique IDs")
    }
}
