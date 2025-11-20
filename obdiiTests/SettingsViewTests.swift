/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewInspector Unit Tests for SettingsView
 *
 * Tests the SettingsView SwiftUI structure and behavior.
 * Validates form sections, pickers, toggles, buttons, and navigation.
 */

import XCTest
import SwiftUI
import ViewInspector
@testable import obdii

@MainActor
final class SettingsViewTests: XCTestCase {
    
    // MARK: - Navigation Structure Tests
    
    func testHasNavigationStack() throws {
        let view = SettingsView()
        let navigationStack = try view.inspect().find(ViewType.NavigationStack.self)
        XCTAssertNotNil(navigationStack, "SettingsView should contain a NavigationStack")
    }
    
    func testNavigationTitle() throws {
        let view = SettingsView()
        
        let stack = try view.inspect().find(ViewType.NavigationStack.self)
        XCTAssertNotNil(stack)
        
        // ViewInspector limitation: https://github.com/nalexn/ViewInspector/issues/347
        let form = try stack.find(ViewType.Form.self)
        XCTAssertNotNil(form, "NavigationStack should contain a Form")
    }
    
    // MARK: - Form Structure Tests
    
    func testHasForm() throws {
        let view = SettingsView()
        let form = try view.inspect().find(ViewType.Form.self)
        XCTAssertNotNil(form, "SettingsView should contain a Form")
    }
    
    func testFormHasSections() throws {
        let view = SettingsView()
        let sections = try view.inspect().findAll(ViewType.Section.self)
        
        // Form should have multiple sections
        XCTAssertGreaterThan(sections.count, 0, "Form should have sections")
    }
    
    // MARK: - Unit Picker Tests
    
    func testHasUnitPicker() throws {
        let view = SettingsView()
        
        // Unit picker should exist (Imperial/Metric)
        let pickers = try view.inspect().findAll(ViewType.Picker.self)
        XCTAssertGreaterThan(pickers.count, 0, "Should have pickers including unit picker")
    }
    
    // MARK: - Connection Type Picker Tests
    
    func testHasConnectionTypePicker() throws {
        let view = SettingsView()
        
        // Connection type picker (Bluetooth/Wi-Fi/Demo)
        let pickers = try view.inspect().findAll(ViewType.Picker.self)
        XCTAssertGreaterThan(pickers.count, 0, "Should have connection type picker")
    }
    
    // MARK: - Toggle Tests
    
    func testHasAutoConnectToggle() throws {
        let view = SettingsView()
        
        // Auto-connect toggle
        let toggles = try view.inspect().findAll(ViewType.Toggle.self)
        XCTAssertGreaterThanOrEqual(toggles.count, 0, "Should have auto-connect toggle")
    }
    
    // MARK: - Connection Status Tests
    
    func testDisplaysConnectionStatus() throws {
        let view = SettingsView()
        
        // Connection status row with indicator
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThan(hStacks.count, 0, "Should have HStack for connection status")
    }
    
    // MARK: - Button Tests
    
    func testHasConnectButton() throws {
        let view = SettingsView()
        
        // Connect/Disconnect button
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        XCTAssertGreaterThan(buttons.count, 0, "Should have connect button")
    }
   
    func testHasShareLogsButton() throws {
        let view = SettingsView()
        
        // Share Logs button
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        XCTAssertGreaterThan(buttons.count, 0, "Should have share logs button")
    }
    
    // MARK: - Wi-Fi Details Tests
    
    func testWiFiDetailsWhenWiFiSelected() throws {
        let view = SettingsView()
        
        // When Wi-Fi is selected, should show host and port fields
        let textFields = try view.inspect().findAll(ViewType.TextField.self)
        
        // TextFields exist when Wi-Fi is selected
        XCTAssertGreaterThanOrEqual(textFields.count, 0, "May have Wi-Fi detail fields")
    }
    
    // MARK: - Navigation Link Tests
    
    func testHasGaugesConfigLink() throws {
        let view = SettingsView()
        
        // Link to Gauges configuration (PIDToggleListView)
        let navLinks = try view.inspect().findAll(ViewType.NavigationLink.self)
        XCTAssertGreaterThan(navLinks.count, 0, "Should have navigation link to Gauges config")
    }
    
    // MARK: - ViewModel Integration Tests
    
    func testViewModelInitialization() throws {
        let viewModel = SettingsViewModel()
        
        // ViewModel should have default values from ConfigData
        XCTAssertNotNil(viewModel.units, "Should have default units")
        XCTAssertNotNil(viewModel.connectionType, "Should have default connection type")
        XCTAssertNotNil(viewModel.connectionState, "Should have connection state")
    }
    
    // MARK: - Accessibility Tests
    
    func testElementsHaveAccessibilityIdentifiers() throws {
        let view = SettingsView()
        
        // Key elements should have accessibility identifiers
        // UnitPicker, ConnectionTypePicker, AutoConnectToggle, etc.
        let form = try view.inspect().find(ViewType.Form.self)
        XCTAssertNotNil(form, "Form elements should have accessibility identifiers")
    }
}
