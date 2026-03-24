import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Hide vault content in the iOS app switcher preview
  override func applicationWillResignActive(_ application: UIApplication) {
    window?.isHidden = true
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    window?.isHidden = false
  }
}
