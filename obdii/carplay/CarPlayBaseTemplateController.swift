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
    }

    // Injected from Scene
    func setTabSelectionPublisher(_ publisher: AnyPublisher<Int, Never>, tabIndex: Int) {
        self.tabIndex = tabIndex
        tabCancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selected in
                guard let self else { return }
                let wasSelected = self.isTabSelected
                self.isTabSelected = (selected == tabIndex)
         
                // If this tab just became selected, force a refresh now.
                if self.isTabSelected && !wasSelected {
                    self.didBecomeVisible()
                }
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
        let allow = isTabSelected
      //  log("refreshIfVisible? selected=\(isTabSelected) visible=\(isTemplateVisible) -> \(allow)")
        guard allow else { return }
        action()
    }

    // Called when the tab becomes selected. Subclasses can override, but default forces a guarded refresh.
    func didBecomeVisible() {
        refreshIfVisible { [weak self] in
            self?.performRefresh()
        }
    }

    // Subclasses should override this to perform their own refresh (e.g., refreshSection/refreshTemplate).
    func performRefresh() {
        // Default does nothing. subclass should override it.
    }

    // Debug helpers
    private func id(_ obj: AnyObject?) -> String {
        guard let obj else { return "nil" }
        return String(describing: Unmanaged.passUnretained(obj).toOpaque())
    }
   
}
