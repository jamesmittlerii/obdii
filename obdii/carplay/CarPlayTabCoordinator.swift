/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * CarPlay tab bar coordinator
 *
 * Manages the tab bar selection state for CarPlay interface, persisting
 * the user's last selected tab across app sessions to provide continuity
 * in the user experience.
 *
 * Uses @AppStorage to automatically save/restore the selected tab index,
 * ensuring the user returns to the same tab they were viewing when they
 * reconnect to CarPlay.
 */
import CarPlay
import SwiftUI

final class CarPlayTabCoordinator: NSObject, CPTabBarTemplateDelegate {
  // Persisted index of the currently selected tab (0-based)
  @AppStorage("selectedCarPlayTab") var selectedIndex: Int = 0
  // Called when the user selects a different tab in the CarPlay interface
  func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect template: CPTemplate) {
    if let index = tabBarTemplate.templates.firstIndex(of: template) {
      selectedIndex = index
    }
  }
}
