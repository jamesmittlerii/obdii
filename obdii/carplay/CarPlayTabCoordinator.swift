/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
CarPlay class to keep track of selected tab to save in settings
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */
import CarPlay
import SwiftUI

final class CarPlayTabCoordinator: NSObject, CPTabBarTemplateDelegate {

    /// Track the currently selected tab index
    @AppStorage("selectedCarPlayTab") var selectedIndex: Int = 0



    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect template: CPTemplate) {
        if let index = tabBarTemplate.templates.firstIndex(of: template) {
            selectedIndex = index
            // Previously sent via Combine publisher; no longer needed.
        } 
    }
}
