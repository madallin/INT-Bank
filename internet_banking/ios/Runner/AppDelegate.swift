import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Must match ScreenSecurityService in lib/core/security/screen_security_service.dart.
  private let screenChannelName = "com.intbank.security/screen"
  private var secureScreenEnabled = false
  private var privacyCover: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: screenChannelName, binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "enableSecureScreen":
          self?.setSecureScreen(true)
          result(true)
        case "disableSecureScreen":
          self?.setSecureScreen(false)
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // iOS cannot block screenshots; instead the app hides its content in the app switcher
    // and while the screen is being recorded or mirrored.
    let center = NotificationCenter.default
    center.addObserver(self, selector: #selector(hideContent), name: UIApplication.willResignActiveNotification, object: nil)
    center.addObserver(self, selector: #selector(updateForCapture), name: UIApplication.didBecomeActiveNotification, object: nil)
    center.addObserver(self, selector: #selector(updateForCapture), name: UIScreen.capturedDidChangeNotification, object: nil)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setSecureScreen(_ enabled: Bool) {
    secureScreenEnabled = enabled
    updateForCapture()
  }

  @objc private func hideContent() {
    if secureScreenEnabled { showPrivacyCover() }
  }

  @objc private func updateForCapture() {
    if secureScreenEnabled && UIScreen.main.isCaptured {
      showPrivacyCover()
    } else if UIApplication.shared.applicationState == .active {
      privacyCover?.removeFromSuperview()
      privacyCover = nil
    }
  }

  private func showPrivacyCover() {
    guard privacyCover == nil, let window = window else { return }
    let cover = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    cover.frame = window.bounds
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(cover)
    privacyCover = cover
  }
}
