/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
CarPlay main scene
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import UIKit
import SwiftOBD2
// CarPlay App Lifecycle

import CarPlay
import os.log
import Combine
import SwiftUI

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    let logger = Logger()
    
    // Models and Services
    private let connectionManager = OBDConnectionManager.shared
    private var measurementCancellable: AnyCancellable?
    private var pidEnabledCancellable: AnyCancellable?   // NEW: observe enabled PID changes
    
    let tabCoordinator = CarPlayTabCoordinator()
    
    // Tab Controllers
    private lazy var gaugesController = CarPlayGaugesController(connectionManager: self.connectionManager)
    private lazy var diagnosticsController = CarPlayDiagnosticsController(connectionManager: self.connectionManager)
    private lazy var settingsController = CarPlaySettingsController()
    private lazy var fuelStatusController = CarPlayFuelStatusController(connectionManager: self.connectionManager)
    private lazy var milStatusController = CarPlayMILStatusController(connectionManager: self.connectionManager)
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
            didConnect interfaceController: CPInterfaceController) {

        self.interfaceController = interfaceController
        
        // Provide the interface controller to each tab controller
        gaugesController.setInterfaceController(interfaceController)
        diagnosticsController.setInterfaceController(interfaceController)
        settingsController.setInterfaceController(interfaceController)
        fuelStatusController.setInterfaceController(interfaceController)
        milStatusController.setInterfaceController(interfaceController)

        // Build the tabs by requesting the root template from each controller
        let gaugesTemplate = gaugesController.makeRootTemplate()
        let fuelStatusTemplate = fuelStatusController.makeRootTemplate()
        let milTemplate = milStatusController.makeRootTemplate()
        let diagnosticsTemplate = diagnosticsController.makeRootTemplate()
        let settingsTemplate = settingsController.makeRootTemplate()

        // Create the tab bar in the same order you will wire tab indices
        let tabBar = CPTabBarTemplate(templates: [
            gaugesTemplate,           // index 0
            fuelStatusTemplate,       // index 1
            milTemplate,              // index 2
            diagnosticsTemplate,      // index 3
            settingsTemplate          // index 4
        ])

        // Coordinator publishes selection and persists last tab
        tabBar.delegate = tabCoordinator

        // Inject selection publisher and tab indices (order must match the templates array above)
        gaugesController.setTabSelectionPublisher(tabCoordinator.selectedIndexPublisher, tabIndex: 0)
        fuelStatusController.setTabSelectionPublisher(tabCoordinator.selectedIndexPublisher, tabIndex: 1)
        milStatusController.setTabSelectionPublisher(tabCoordinator.selectedIndexPublisher, tabIndex: 2)
        diagnosticsController.setTabSelectionPublisher(tabCoordinator.selectedIndexPublisher, tabIndex: 3)
        settingsController.setTabSelectionPublisher(tabCoordinator.selectedIndexPublisher, tabIndex: 4)

        // Optionally select the persisted tab initially if in range
        let initialIndex = UserDefaults.standard.integer(forKey: "selectedCarPlayTab")
        if (0..<tabBar.templates.count).contains(initialIndex) {
            // Many SDKs don’t support the selectedTemplate: overload; just update templates.
            tabBar.updateTemplates(tabBar.templates)
        }

        interfaceController.setRootTemplate(tabBar,
                                            animated: true,
                                            completion: nil)
        
        // Start OBD-II connection automatically if enabled
        if ConfigData.shared.autoConnectToOBD {
            Task {
                await connectionManager.connect()
            }
        }
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        measurementCancellable?.cancel()
        pidEnabledCancellable?.cancel() // NEW: cancel the PID enabled subscription
    }
}

