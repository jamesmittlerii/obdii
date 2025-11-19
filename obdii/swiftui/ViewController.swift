/**
 
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * UIKit wrapper for the main SwiftUI tab interface,
 * including a one-time safety popup reminding the user
 * not to adjust settings while driving.
 *
 */

import UIKit
import SwiftUI

final class ViewController: UIViewController {

    private let carPlayPromptKey = "HasShownCarPlayDrivingPrompt"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Wrap SwiftUI root view
        let hostingVC = UIHostingController(rootView: RootTabView())

        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingVC.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Show one-time alert
        if shouldShowSafetyPrompt {
            presentCarPlayDrivingPrompt()
            markSafetyPromptShown()
        }
    }

    // MARK: - One-Time Prompt Logic

    private var shouldShowSafetyPrompt: Bool {
        !UserDefaults.standard.bool(forKey: carPlayPromptKey)
    }

    private func markSafetyPromptShown() {
        UserDefaults.standard.set(true, forKey: carPlayPromptKey)
    }

    private func presentCarPlayDrivingPrompt() {
        let alert = UIAlertController(
            title: "Safety Reminder",
            message: "For your safety, please avoid changing settings while driving.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))

        // Present safely on main queue
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.presentedViewController == nil {
                self.present(alert, animated: true)
            }
        }
    }
}
