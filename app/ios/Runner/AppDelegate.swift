import Flutter
import UIKit

/// Exposes iOS Low Power Mode to Dart (channel `scenelex/power_mode`).
private class PowerModePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PowerModePlugin()
    let methodChannel = FlutterMethodChannel(
      name: "scenelex/power_mode",
      binaryMessenger: registrar.messenger()
    )
    methodChannel.setMethodCallHandler(instance.handleMethod)
    let eventChannel = FlutterEventChannel(
      name: "scenelex/power_mode/events",
      binaryMessenger: registrar.messenger()
    )
    eventChannel.setStreamHandler(instance)
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(instance.powerStateDidChange),
      name: .NSProcessInfoPowerStateDidChange,
      object: nil
    )
  }

  private func handleMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isLowPowerEnabled":
      result(ProcessInfo.processInfo.isLowPowerModeEnabled)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func powerStateDidChange() {
    eventSink?(ProcessInfo.processInfo.isLowPowerModeEnabled)
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    events(ProcessInfo.processInfo.isLowPowerModeEnabled)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PowerModePlugin") {
      PowerModePlugin.register(with: registrar)
    }
  }
}
