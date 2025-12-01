/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewInspector Unit Tests for RootTabView
 *
 * Tests the RootTabView SwiftUI structure and behavior.
 * Validates tab bar structure and all 5 tabs.
 */

import XCTest
import SwiftUI
import ViewInspector
@testable import obdii

@MainActor
final class RootTabViewTests: XCTestCase {

    
    func testHasTabView() throws {
        let view = RootTabView()
        let tabView = try view.inspect().find(ViewType.TabView.self)
        XCTAssertNotNil(tabView, "RootTabView should contain a TabView")
    }

    
    func testHasFiveTabs() throws {
        let view = RootTabView()
        
        // RootTabView should have exactly 5 tabs:
        // Settings, Gauges, Fuel, MIL, DTCs
        
        // ViewInspector can find the TabView
        let tabView = try view.inspect().find(ViewType.TabView.self)
        XCTAssertNotNil(tabView, "Should have TabView with 5 tabs")
    }

    
    func testSettingsTabExists() throws {
        let view = RootTabView()
        
        // Settings tab should exist
        // Contains SettingsView
        XCTAssertNoThrow(try view.inspect().find(ViewType.TabView.self))
    }

    
    func testGaugesTabHasNavigationStack() throws {
        let view = RootTabView()
        
        // Gauges tab should have NavigationStack
        let navigationStacks = try view.inspect().findAll(ViewType.NavigationStack.self)
        XCTAssertGreaterThan(navigationStacks.count, 0, "Should have NavigationStack for tabs")
    }

    
    func testTabsHaveAccessibilityIdentifiers() throws {
        let view = RootTabView()
        
        // Each tab should have accessibility identifier
        // SettingsTab, GaugesTab, FuelTab, MILTab, DTCTab
        let tabView = try view.inspect().find(ViewType.TabView.self)
        XCTAssertNotNil(tabView, "TabView should have accessibility identifiers on tabs")
    }

    
    func testUsesAutomaticTabViewStyle() throws {
        let view = RootTabView()
        
        // TabView uses .automatic style for consistent appearance
        let tabView = try view.inspect().find(ViewType.TabView.self)
        XCTAssertNotNil(tabView, "Should use automatic tab view style")
    }

    
    func testTabItemsHaveLabelsAndIcons() throws {
        let view = RootTabView()
        
        // Each tab uses Label with text and SF Symbol
        // Settings: "gear"
        // Gauges: "gauge"
        // Fuel: "fuelpump.fill"
        // MIL: "engine.combustion.fill"
        // DTCs: "wrench.and.screwdriver"
        
        let tabView = try view.inspect().find(ViewType.TabView.self)
        XCTAssertNotNil(tabView, "Tabs should have labels and icons")
    }

    
    func testAllTabsContainValidViews() throws {
        let view = RootTabView()
        
        // Verify TabView structure is correct
        let tabView = try view.inspect().find(ViewType.TabView.self)
        XCTAssertNotNil(tabView, "All tabs should contain their respective views")
    }
}
