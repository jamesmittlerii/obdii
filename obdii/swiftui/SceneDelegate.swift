/**

 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Main Scene delegate (entry point) for Phone UI
 *
 */

import UIKit

// Reads the device model identifier, e.g. "iPhone15,3", "iPad14,1".
func deviceModelIdentifier() -> String {
  var systemInfo = utsname()
  uname(&systemInfo)

  return withUnsafePointer(to: &systemInfo.machine) { ptr in
    ptr.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
      String(cString: $0).trimmingCharacters(in: .controlCharacters)
    }
  }
}
// Check for real iPad hardware (useful when iPadOS simulates iPhone UI idioms).
func isRunningOniPadHardware() -> Bool {
  deviceModelIdentifier().hasPrefix("iPad")
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let window = UIWindow(windowScene: windowScene)
    #if false
      if UIDevice.current.userInterfaceIdiom == .pad || isRunningOniPadHardware() {
        window.rootViewController = UnsupportedDeviceViewController()
        self.window = window
        window.makeKeyAndVisible()
        return
      }
    #endif
    window.rootViewController = ViewController()
    self.window = window
    window.makeKeyAndVisible()
  }
}
// Displayed on iPad if iPad usage is blocked (used for release scenarios only).
final class UnsupportedDeviceViewController: UIViewController {

  private let message: String =
    "This CarPlay-enabled app is not supported on iPad."

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .systemBackground

    let label = UILabel()
    label.text = message
    label.font = .preferredFont(forTextStyle: .body)
    label.textAlignment = .center
    label.numberOfLines = 0
    label.textColor = .label
    label.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(label)

    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
      label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
  }
}
