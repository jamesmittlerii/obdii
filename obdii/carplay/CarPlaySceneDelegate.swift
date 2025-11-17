/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
Main carplay entrypoint. Do initialization.
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import UIKit
import SwiftOBD2
import CarPlay
import os.log
import Combine
import SwiftUI

// need a definition so we can iterate over our tabs for repetitive actions
protocol CarPlayTabControlling: AnyObject {
    /// Return the root CPTemplate for this tab.
    func makeRootTemplate() -> CPTemplate

    /// Called when the CarPlaySceneDelegate supplies the active interface controller.
    func setInterfaceController(_ interfaceController: CPInterfaceController)

    /// Called when the tab coordinator publishes tab selections.
    func setTabSelectionPublisher(_ publisher: AnyPublisher<Int, Never>, tabIndex: Int)
}

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPInterfaceControllerDelegate {

    var interfaceController: CPInterfaceController?
    private let logger = Logger()
    private let connectionManager = OBDConnectionManager.shared
    private let tabCoordinator = CarPlayTabCoordinator()

    // Registry: map templates to their owning controllers so we can forward appear/disappear
    private var ownerByTemplateID: [ObjectIdentifier: AnyObject] = [:]

    // Tab Controllers
    private lazy var controllers: [any CarPlayTabControlling] = [
        CarPlayGaugesController(),
        CarPlayFuelStatusController(),
        CarPlayMILStatusController(),
        CarPlayDiagnosticsController(),
        CarPlaySettingsController()
    ]

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {

        self.interfaceController = interfaceController
        interfaceController.delegate = self

        // 1) Provide interface controller to all tab controllers
        controllers.forEach { $0.setInterfaceController(interfaceController) }

        // 2) Build templates from controllers
        let templates = controllers.map { $0.makeRootTemplate() }

        // 2a) Register ownership for visibility forwarding (store as AnyObject)
        for (index, controller) in controllers.enumerated() {
            let template = templates[index]
            ownerByTemplateID[ObjectIdentifier(template)] = controller as AnyObject
        }

        // 3) Create tab bar
        let tabBar = CPTabBarTemplate(templates: templates)
        tabBar.delegate = tabCoordinator

        /*
        // 4) Inject selection publisher + index for each controller
        for (index, controller) in controllers.enumerated() {
            controller.setTabSelectionPublisher(
                tabCoordinator.selectedIndexPublisher,
                tabIndex: index
            )
        }*/

        // 5) Set root template
        interfaceController.setRootTemplate(tabBar, animated: true, completion: nil)

        // 6) Restore previous tab selection (async required due to CarPlay timing)
        let savedIndex = UserDefaults.standard.integer(forKey: "selectedCarPlayTab")

        DispatchQueue.main.async { [weak tabBar] in
            guard let tabBar, (0..<tabBar.templates.count).contains(savedIndex) else { return }
            tabBar.selectTemplate(at: savedIndex)
        }

        // 7) Auto-connect to OBD if enabled
        if ConfigData.shared.autoConnectToOBD {
            Task { await connectionManager.connect() }
        }
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
            didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        ownerByTemplateID.removeAll()
    }

    // MARK: - CPInterfaceControllerDelegate (visibility forwarding)

    func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {
        guard let owner = ownerByTemplateID[ObjectIdentifier(aTemplate)] as? CarPlayVisibilityForwarding else { return }
        owner.templateDidAppear(aTemplate)
    }

    func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {
        guard let owner = ownerByTemplateID[ObjectIdentifier(aTemplate)] as? CarPlayVisibilityForwarding else { return }
        owner.templateDidDisappear(aTemplate)
    }

    // Older iOS compatibility (if needed)
    func interfaceController(_ interfaceController: CPInterfaceController, didShow template: CPTemplate, animated: Bool) {
        templateDidAppear(template, animated: animated)
    }

    func interfaceController(_ interfaceController: CPInterfaceController, didHide template: CPTemplate, animated: Bool) {
        templateDidDisappear(template, animated: animated)
    }

    // Unregister mapping when a template is popped off the stack
    func interfaceController(_ interfaceController: CPInterfaceController, didPop template: CPTemplate, to newTopTemplate: CPTemplate, animated: Bool) {
        unregister(template: template)
    }

    // Public helper to register ownership for pushed templates
    func register(template: CPTemplate, owner: AnyObject) {
        ownerByTemplateID[ObjectIdentifier(template)] = owner
    }

    func unregister(template: CPTemplate) {
        ownerByTemplateID.removeValue(forKey: ObjectIdentifier(template))
    }
}

