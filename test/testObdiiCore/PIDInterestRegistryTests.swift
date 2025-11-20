/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for PIDInterestRegistry
 *
 * Tests demand-driven polling token management, PID interest registration,
 * replacement, clearing, and interested PIDs computation.
 */

import XCTest
import SwiftOBD2
import Combine
@testable import obdii

@MainActor
final class PIDInterestRegistryTests: XCTestCase {
    
    var registry: PIDInterestRegistry!
    
    override func setUp() async throws {
        registry = PIDInterestRegistry.shared
    }
    
    override func tearDown() async throws {
        registry = nil
    }
    
    // MARK: - Initialization Tests
    
    func testSharedInstanceExists() {
        XCTAssertNotNil(PIDInterestRegistry.shared, "Shared instance should exist")
    }
    
    // MARK: - Token Creation Tests
    
    func testMakeToken() {
        let token1 = registry.makeToken()
        let token2 = registry.makeToken()
        
        XCTAssertNotEqual(token1, token2, "Each token should be unique")
    }
    
    // MARK: - Replace PIDs Tests
    
    func testReplacePIDsForToken() {
        let token = registry.makeToken()
        let pids: Set<OBDCommand> = [.mode1(.rpm), .mode1(.speed)]
        
        registry.replace(pids: pids, for: token)
        
        // Should now have interested PIDs
        XCTAssertFalse(registry.interested.isEmpty, "Should have interested PIDs")
        XCTAssertTrue(registry.interested.contains(.mode1(.rpm)), "Should contain RPM")
        XCTAssertTrue(registry.interested.contains(.mode1(.speed)), "Should contain Speed")
    }
    
    func testReplaceOverwritesPreviousPIDs() {
        let token = registry.makeToken()
        
        // First set
        registry.replace(pids: [.mode1(.rpm)], for: token)
        XCTAssertTrue(registry.interested.contains(.mode1(.rpm)))
        
        // Replace with different set
        registry.replace(pids: [.mode1(.speed)], for: token)
        XCTAssertFalse(registry.interested.contains(.mode1(.rpm)), "Old PID should be removed")
        XCTAssertTrue(registry.interested.contains(.mode1(.speed)), "New PID should be added")
    }
    
    func testReplaceWithEmptySet() {
        let token = registry.makeToken()
        
        registry.replace(pids: [.mode1(.rpm)], for: token)
        XCTAssertTrue(registry.interested.contains(.mode1(.rpm)))
        
        // Replace with empty set
        registry.replace(pids: [], for: token)
        XCTAssertFalse(registry.interested.contains(.mode1(.rpm)), "Should clear token's PIDs")
    }
    
    // MARK: - Multiple Tokens Tests
    
    func testMultipleTokensCanRegisterSamePID() {
        let token1 = registry.makeToken()
        let token2 = registry.makeToken()
        
        registry.replace(pids: [.mode1(.rpm)], for: token1)
        registry.replace(pids: [.mode1(.rpm)], for: token2)
        
        // RPM should be in interested set
        XCTAssertTrue(registry.interested.contains(.mode1(.rpm)))
    }
    
    func testMultipleTokensWithDifferentPIDs() {
        let token1 = registry.makeToken()
        let token2 = registry.makeToken()
        
        registry.replace(pids: [.mode1(.rpm)], for: token1)
        registry.replace(pids: [.mode1(.speed)], for: token2)
        
        // Both should be in interested set
        XCTAssertTrue(registry.interested.contains(.mode1(.rpm)))
        XCTAssertTrue(registry.interested.contains(.mode1(.speed)))
        XCTAssertEqual(registry.interested.count, 2, "Should have 2 interested PIDs")
    }
    
    // MARK: - Clear Token Tests
    
    func testClearToken() async {
        let token = registry.makeToken()
        
        registry.replace(pids: [.mode1(.rpm)], for: token)
        XCTAssertTrue(registry.interested.contains(.mode1(.rpm)))
        
        // clear() is async and yields
        registry.clear(token: token)
        
        // Wait for async clear
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
        
        XCTAssertFalse(registry.interested.contains(.mode1(.rpm)), "Should clear token's PIDs")
    }
    
    func testClearTokenDoesNotAffectOtherTokens() async {
        let token1 = registry.makeToken()
        let token2 = registry.makeToken()
        
        registry.replace(pids: [.mode1(.rpm)], for: token1)
        registry.replace(pids: [.mode1(.speed)], for: token2)
        
        registry.clear(token: token1)
        
        // Wait for async clear
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertFalse(registry.interested.contains(.mode1(.rpm)), "Token1's PID should be cleared")
        XCTAssertTrue(registry.interested.contains(.mode1(.speed)), "Token2's PID should remain")
    }
    
    func testClearSharedPID() async {
        let token1 = registry.makeToken()
        let token2 = registry.makeToken()
        
        // Both tokens register RPM
        registry.replace(pids: [.mode1(.rpm)], for: token1)
        registry.replace(pids: [.mode1(.rpm)], for: token2)
        
        // Clear one token
        registry.clear(token: token1)
        
        // Wait for async clear
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // RPM should still be interested (token2 still has it)
        XCTAssertTrue(registry.interested.contains(.mode1(.rpm)), 
                     "Shared PID should remain while other token holds it")
    }
    
    // MARK: - Interested PIDs Tests
    
    func testInterestedPIDsUnion() {
        let token1 = registry.makeToken()
        let token2 = registry.makeToken()
        
        registry.replace(pids: [.mode1(.rpm), .mode1(.coolantTemp)], for: token1)
        registry.replace(pids: [.mode1(.speed), .mode1(.rpm)], for: token2)
        
        // Should be union of all registered PIDs
        XCTAssertEqual(registry.interested.count, 3, "Should have 3 unique PIDs")
        XCTAssertTrue(registry.interested.contains(.mode1(.rpm)))
        XCTAssertTrue(registry.interested.contains(.mode1(.speed)))
        XCTAssertTrue(registry.interested.contains(.mode1(.coolantTemp)))
    }
    
    // MARK: - Published Property Tests
    
    func testInterestedIsPublished() {
        var changeCount = 0
        let token = registry.makeToken()
        
        let cancellable = registry.$interested.sink { _ in
            changeCount += 1
        }
        
        // Trigger a change
        registry.replace(pids: [.mode1(.rpm)], for: token)
        
        XCTAssertGreaterThan(changeCount, 1, "interested should publish changes")
        
        cancellable.cancel()
    }
}
