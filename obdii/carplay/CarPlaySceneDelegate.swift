/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * CarPlay scene delegate - main entry point for CarPlay interface
 *
 * Responsibilities:
 * - Initialize and manage the CarPlay tab bar interface
 * - Create and configure all tab controllers (Gauges, Fuel Status, MIL, DTCs, Settings)
 * - Manage template lifecycle and visibility tracking
 * - Forward template appear/disappear events to appropriate controllers
 * - Restore user's last selected tab on reconnection
 * - Auto-connect to OBD-II if configured
 *
 * The delegate maintains a registry mapping templates to their owning controllers,
 * enabling proper visibility event forwarding for demand-driven PID polling.
 */

import CarPlay
import Combine
import SwiftOBD2
import SwiftUI
import UIKit
import os.log

// Protocol for CarPlay tab controllers, enables uniform initialization and configuration.
protocol CarPlayTabControlling: AnyObject {
  // Return the root CPTemplate for this tab.
  func makeRootTemplate() -> CPTemplate
  // Called when the CarPlaySceneDelegate supplies the active interface controller.
  func setInterfaceController(_ interfaceController: CPInterfaceController)
}

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate,
  CPInterfaceControllerDelegate
{

  var interfaceController: CPInterfaceController?
  private let logger = Logger()
  private let connectionManager = OBDConnectionManager.shared
  private let tabCoordinator = CarPlayTabCoordinator()
  // Registry mapping templates to their owning controllers for visibility event forwarding.
  // Allows the scene delegate to notify controllers when their templates appear/disappear.
  private var ownerByTemplateID: [ObjectIdentifier: AnyObject] = [:]
  // All tab controllers in display order (Gauges, Fuel Status, MIL, DTCs, Settings)
  private lazy var controllers: [any CarPlayTabControlling] = [
    CarPlayGaugesController(),
    CarPlayFuelStatusController(),
    CarPlayMILStatusController(),
    CarPlayDiagnosticsController(),
    CarPlaySettingsController(),
  ]

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {

    self.interfaceController = interfaceController
    interfaceController.delegate = self

    // 1) Provide interface controller to all tab controllers
    controllers.forEach { $0.setInterfaceController(interfaceController) }

    // 2) Build templates from controllers
    let templates = controllers.map { $0.makeRootTemplate() }

    // 3) Register ownership for visibility forwarding
    for (index, controller) in controllers.enumerated() {
      let template = templates[index]
      ownerByTemplateID[ObjectIdentifier(template)] = controller as AnyObject
    }

    // 4) Create tab bar with coordinator delegate
    let tabBar = CPTabBarTemplate(templates: templates)
    tabBar.delegate = tabCoordinator

    // 5) Set root template
    interfaceController.setRootTemplate(tabBar, animated: true, completion: nil)

    // 6) Restore previous tab selection (async required due to CarPlay timing)
    let savedIndex = tabCoordinator.selectedIndex

    DispatchQueue.main.async { [weak tabBar] in
      guard let tabBar, (0..<tabBar.templates.count).contains(savedIndex) else { return }
      tabBar.selectTemplate(at: savedIndex)
    }

    // 7) Auto-connect to OBD-II if enabled in settings
    if ConfigData.shared.autoConnectToOBD {
      Task { await connectionManager.connect() }
    }
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnectInterfaceController interfaceController: CPInterfaceController
  ) {
    self.interfaceController = nil
    ownerByTemplateID.removeAll()
  }

  func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {
    guard let owner = ownerByTemplateID[ObjectIdentifier(aTemplate)] as? CarPlayVisibilityForwarding
    else { return }
    owner.templateDidAppear(aTemplate)
  }

  func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {
    guard let owner = ownerByTemplateID[ObjectIdentifier(aTemplate)] as? CarPlayVisibilityForwarding
    else { return }
    owner.templateDidDisappear(aTemplate)
  }

  func interfaceController(
    _ interfaceController: CPInterfaceController, didShow template: CPTemplate, animated: Bool
  ) {
    templateDidAppear(template, animated: animated)
  }

  func interfaceController(
    _ interfaceController: CPInterfaceController, didHide template: CPTemplate, animated: Bool
  ) {
    templateDidDisappear(template, animated: animated)
  }
  // Called when a template is popped from the navigation stack - cleanup registry
  func interfaceController(
    _ interfaceController: CPInterfaceController, didPop template: CPTemplate,
    to newTopTemplate: CPTemplate, animated: Bool
  ) {
    unregister(template: template)
  }
  // Register a template's owning controller for visibility event forwarding.
  // Called by controllers when pushing detail templates (e.g., gauge detail view).
  func register(template: CPTemplate, owner: AnyObject) {
    ownerByTemplateID[ObjectIdentifier(template)] = owner
  }
  // Remove a template from the registry when it's dismissed or deallocated
  func unregister(template: CPTemplate) {
    ownerByTemplateID.removeValue(forKey: ObjectIdentifier(template))
  }
}
