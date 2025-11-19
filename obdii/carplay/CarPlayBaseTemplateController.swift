/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Base class for CarPlay tab templates
 *
 * This base controller provides:
 * - Template lifecycle management (creation, visibility tracking)
 * - View model integration with automatic refresh on changes
 * - Demand-driven PID polling via PIDInterestRegistry tokens
 * - Visibility-aware refresh behavior (only updates when tab is active)
 *
 * CarPlay requires manual visibility tracking unlike SwiftUI. This class ensures
 * templates only refresh and request PID data when their tab is actively visible,
 * preventing unnecessary updates and resource usage.
 *
 * Subclasses should override:
 * - `makeRootTemplate()` - Create the initial template for this tab
 * - `performRefresh()` - Update the template when data changes
 * - `registerVisiblePIDs()` - Specify which PIDs to poll when visible
 */


import CarPlay
import Combine
import SwiftOBD2

// Non-generic protocol to allow CarPlaySceneDelegate to forward visibility
@MainActor
protocol CarPlayVisibilityForwarding: AnyObject {
    func templateDidAppear(_ template: CPTemplate)
    func templateDidDisappear(_ template: CPTemplate)
}

@MainActor
class CarPlayBaseTemplateController<VM: BaseViewModel>: NSObject, @MainActor CarPlayTabControlling, CarPlayVisibilityForwarding {
    weak var interfaceController: CPInterfaceController?
    var currentTemplate: CPTemplate?
    var isVisible = false
   let viewModel: VM
 
    // Demand-driven polling token for this controller
    let controllerToken: UUID = PIDInterestRegistry.shared.makeToken()

    // MARK: - Init

    init(viewModel: VM) {
        self.viewModel = viewModel
        super.init()
    }

    // MARK: - CarPlayTabControlling

    func makeRootTemplate() -> CPTemplate {
        let template = CPListTemplate(title: "", sections: [])
        self.currentTemplate = template
        return template
    }

    func setInterfaceController(_ interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        
        // Listen to view model changes only (no direct OBDConnectionManager usage)
        viewModel.onChanged = { [weak self] in
            self?.performRefresh()
        }
    }

    // Subclasses should override this to perform their own refresh (e.g., refreshSection/refreshTemplate).
    func performRefresh() {
        // Default does nothing. subclass should override it.
    }

    // Subclasses can override to register their currently visible PIDs.
    func registerVisiblePIDs() {
        // Default does nothing.
    }

    // Debug helpers
    private func id(_ obj: AnyObject?) -> String {
        guard let obj else { return "nil" }
        return String(describing: Unmanaged.passUnretained(obj).toOpaque())
    }
   
    // MARK: - Template visibility hooks (to be called by the CPInterfaceController delegate)

    /// Call when a CPTemplate did appear. If it is our currentTemplate, we refresh and register interest.
    func templateDidAppear(_ template: CPTemplate) {
        guard let currentTemplate, template === currentTemplate else { return }
        let owner = String(describing: type(of: self))
        let tid = id(template)
        obdDebug("CarPlay templateDidAppear: \(owner) template=\(tid)", category: .service)
        isVisible = true
        performRefresh()
        registerVisiblePIDs()
    }

    /// Call when a CPTemplate did disappear. If it is our currentTemplate, clear our PID interest.
    func templateDidDisappear(_ template: CPTemplate) {
        guard let currentTemplate, template === currentTemplate else { return }
        let owner = String(describing: type(of: self))
        let tid = id(template)
        obdDebug("CarPlay templateDidDisappear: \(owner) template=\(tid)", category: .service)
        isVisible = false
        PIDInterestRegistry.shared.clear(token: controllerToken)
    }
}
