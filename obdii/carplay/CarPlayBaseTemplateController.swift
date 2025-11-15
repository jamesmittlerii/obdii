import CarPlay
import Combine

@MainActor
class CarPlayBaseTemplateController: NSObject {
    weak var interfaceController: CPInterfaceController?
    var currentTemplate: CPTemplate?

    // Tab selection
    private var tabIndex: Int = 0
    private var isTabSelected = false
    private var tabCancellable: AnyCancellable?

    func setInterfaceController(_ interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        log("setInterfaceController: \(id(interfaceController))")
    }

    // Injected from Scene
    func setTabSelectionPublisher(_ publisher: AnyPublisher<Int, Never>, tabIndex: Int) {
        self.tabIndex = tabIndex
        tabCancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selected in
                guard let self else { return }
                self.isTabSelected = (selected == tabIndex)
                self.log("tab selection updated: selected=\(selected) mine=\(tabIndex) active=\(self.isTabSelected)")
            }
    }

    // Strictly on-screen check
    var isTemplateVisible: Bool {
        guard let interfaceController, let currentTemplate,
              let top = interfaceController.topTemplate else { return false }
        return top === currentTemplate
    }

    // Gate UI updates by tab selection (and optionally visibility)
    func refreshIfVisible(_ action: () -> Void) {
        let allow = isTabSelected && isTemplateVisible
        log("refreshIfVisible? selected=\(isTabSelected) visible=\(isTemplateVisible) -> \(allow)")
        guard allow else { return }
        action()
    }

    // Debug helpers
    private func id(_ obj: AnyObject?) -> String {
        guard let obj else { return "nil" }
        return String(describing: Unmanaged.passUnretained(obj).toOpaque())
    }
    private func log(_ message: String) { print("[CarPlayBase] \(message)") }
}
