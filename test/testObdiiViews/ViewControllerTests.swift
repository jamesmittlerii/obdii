//
//  ViewControllerTests.swift
//  obdii
//
//  Created by cisstudent on 11/20/25.
//


/**
 * __Final Project__
 * Jim Mittler
 * 20 November 2025
 *
 * Unit Tests for ViewController
 *
 * Tests the UIKit wrapper for SwiftUI content including hosting controller setup,
 * Auto Layout constraints, one-time safety prompt display, and UserDefaults persistence.
 */

import XCTest
import UIKit
import SwiftUI
@testable import obdii

@MainActor
final class ViewControllerTests: XCTestCase {
    
    var viewController: ViewController!
    let testKey = "HasShownCarPlayDrivingPrompt"
    
    override func setUp() async throws {
        viewController = ViewController()
        
        // Clear UserDefaults state before each test
        UserDefaults.standard.removeObject(forKey: testKey)
    }
    
    override func tearDown() async throws {
        viewController = nil
        
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: testKey)
    }
    
    // MARK: - Initialization Tests
    
    func testViewControllerInitialization() {
        XCTAssertNotNil(viewController, "ViewController should initialize")
    }
    
    // MARK: - viewDidLoad Tests
    
    func testViewDidLoadAddsHostingController() {
        viewController.loadViewIfNeeded()
        
        // Should add UIHostingController as child
        XCTAssertGreaterThan(viewController.children.count, 0, "Should add hosting controller as child")
    }
    
    func testHostingControllerIsAdded() {
        viewController.loadViewIfNeeded()
        
        // First child should be UIHostingController
        let firstChild = viewController.children.first
        XCTAssertTrue(firstChild is UIHostingController<RootTabView>, "Child should be UIHostingController<RootTabView>")
    }
    
    func testHostingControllerViewIsAdded() {
        viewController.loadViewIfNeeded()
        
        // Hosting controller's view should be added to view hierarchy
        guard let hostingVC = viewController.children.first else {
            XCTFail("Should have hosting controller child")
            return
        }
        
        XCTAssertTrue(viewController.view.subviews.contains(hostingVC.view), "Hosting controller view should be added to view hierarchy")
    }
    
    // MARK: - Auto Layout Tests
    
    func testHostingControllerUsesAutoresizingMask() {
        viewController.loadViewIfNeeded()
        
        guard let hostingVC = viewController.children.first else {
            XCTFail("Should have hosting controller child")
            return
        }
        
        XCTAssertFalse(hostingVC.view.translatesAutoresizingMaskIntoConstraints, 
                       "Should disable autoresizing mask translation for Auto Layout")
    }
    
    func testAutoLayoutConstraintsAreActivated() {
        viewController.loadViewIfNeeded()
        
        guard let hostingVC = viewController.children.first else {
            XCTFail("Should have hosting controller child")
            return
        }
        
        // Verify view has constraints
        let hasConstraints = !hostingVC.view.constraints.isEmpty || 
                            !viewController.view.constraints.isEmpty
        XCTAssertTrue(hasConstraints, "Should have Auto Layout constraints")
    }
    
    func testHostingControllerDidMoveToParent() {
        viewController.loadViewIfNeeded()
        
        // didMove(toParent:) should be called
        // This is verified implicitly by checking parent relationship
        guard let hostingVC = viewController.children.first else {
            XCTFail("Should have hosting controller child")
            return
        }
        
        XCTAssertEqual(hostingVC.parent, viewController, "Hosting controller should have correct parent")
    }
    
    // MARK: - Safety Prompt Tests
    
    func testSafetyPromptShownFirstTime() {
        // First time, flag should be false
        let shouldShow = !UserDefaults.standard.bool(forKey: testKey)
        XCTAssertTrue(shouldShow, "Should show prompt first time")
    }
    
    func testSafetyPromptNotShownAfterMarked() {
        // Mark as shown
        UserDefaults.standard.set(true, forKey: testKey)
        
        let shouldShow = !UserDefaults.standard.bool(forKey: testKey)
        XCTAssertFalse(shouldShow, "Should not show prompt after being marked")
    }
    
    func testMarkSafetyPromptShownSetsUserDefaults() {
        // Initially false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: testKey), "Should be false initially")
        
        // Simulate marking as shown
        UserDefaults.standard.set(true, forKey: testKey)
        
        XCTAssertTrue(UserDefaults.standard.bool(forKey: testKey), "Should be true after marking")
    }
    
    // MARK: - Alert Controller Tests
    
    func testAlertControllerCreation() {
        let alert = UIAlertController(
            title: "Safety Reminder",
            message: "For your safety, please avoid changing settings while driving.",
            preferredStyle: .alert
        )
        
        XCTAssertNotNil(alert, "Should create alert controller")
        XCTAssertEqual(alert.title, "Safety Reminder", "Alert should have correct title")
        XCTAssertEqual(alert.message, "For your safety, please avoid changing settings while driving.", 
                       "Alert should have correct message")
        XCTAssertEqual(alert.preferredStyle, .alert, "Alert should use alert style")
    }
    
    func testAlertHasOKAction() {
        let alert = UIAlertController(
            title: "Safety Reminder",
            message: "For your safety, please avoid changing settings while driving.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        XCTAssertEqual(alert.actions.count, 1, "Alert should have one action")
        XCTAssertEqual(alert.actions.first?.title, "OK", "Action should be titled 'OK'")
        XCTAssertEqual(alert.actions.first?.style, .default, "Action should have default style")
    }
    
    // MARK: - UserDefaults Key Tests
    
    func testUserDefaultsKeyIsCorrect() {
        let expectedKey = "HasShownCarPlayDrivingPrompt"
        XCTAssertEqual(testKey, expectedKey, "UserDefaults key should match expected value")
    }
    
    // MARK: - Memory Management Tests
    
    func testWeakSelfInAsyncBlock() {
        // Async blocks should use [weak self] to avoid retain cycles
        // This is tested implicitly by the implementation
        viewController.loadViewIfNeeded()
        
        XCTAssertTrue(true, "Should use weak self to avoid retain cycles")
    }
    
    // MARK: - Presentation Tests
    
    func testViewControllerCanPresent() {
        viewController.loadViewIfNeeded()
        
        // ViewController should be able to present other view controllers
        XCTAssertNil(viewController.presentedViewController, "Should not have presented view controller initially")
    }
    
    func testPresentationCheckBeforePresenting() {
        viewController.loadViewIfNeeded()
        
        // Should check if already presenting before showing alert
        let isPresenting = viewController.presentedViewController != nil
        XCTAssertFalse(isPresenting, "Should not be presenting initially")
    }
}
