import Cocoa
import FlutterMacOS
import Carbon

@main
class AppDelegate: FlutterAppDelegate {
  private var eventMonitor: Any?
  private var hotkeyChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }

    hotkeyChannel = FlutterMethodChannel(
      name: "com.trareon.global_hotkey",
      binaryMessenger: controller.engine.binaryMessenger
    )

    // Global event monitor — fires even when app is in background.
    // Requires Accessibility permissions (System Settings → Privacy & Security
    // → Accessibility). First launch will prompt macOS; subsequent launches
    // silently degrade if permission is denied.
    eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.handleGlobalKeyEvent(event)
    }
  }

  private func handleGlobalKeyEvent(_ event: NSEvent) {
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    let hasControl = modifiers.contains(.control)
    let hasShift = modifiers.contains(.shift)

    guard hasControl && hasShift else { return }

    switch Int(event.keyCode) {
    case kVK_ANSI_R:  // Ctrl+Shift+R → start/stop recording
      hotkeyChannel?.invokeMethod("startStop", arguments: nil)
    case kVK_ANSI_P:  // Ctrl+Shift+P → pause/resume
      hotkeyChannel?.invokeMethod("pauseResume", arguments: nil)
    default:
      break
    }
  }

  deinit {
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
    }
  }
}
