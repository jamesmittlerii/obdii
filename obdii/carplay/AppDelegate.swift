/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
Main launcher for CarPlay
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */
import UIKit
import OSLog


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // Define an app-wide logger
    static let logger = Logger(subsystem: "com.rheosoft.obdii", category: "AppInit")

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // App-level setup only
        return true
    }
}
