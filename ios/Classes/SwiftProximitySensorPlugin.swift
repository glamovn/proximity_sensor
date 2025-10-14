import Flutter
  import UIKit

  //==============================================================================
  public class SwiftProximityStreamHandler : NSObject, FlutterStreamHandler
  {
      // MARK: - Properties
      var eventSink: FlutterEventSink?
      var lastReportedValue: Int8?

      // Notification-based detection
      private var notificationObserver: NSObjectProtocol?

      // Polling backup mechanism
      private var pollTimer: Timer?
      private var lastNotificationTime: Date?
      private let notificationTimeoutInterval: TimeInterval = 2.0  // 2s without notification = polling kicks in
      private let normalPollingInterval: TimeInterval = 1.0        // Slow polling when notifications work
      private let activePollingInterval: TimeInterval = 0.2        // Fast polling when notifications fail

      // Configuration
      private let brightnessThreshold: Double = 0.1

      #if DEBUG
      private let debugLogging = true
      #else
      private let debugLogging = false
      #endif

      // MARK: - Logging
      private func log(_ message: String) {
          if debugLogging {
              print("ProximitySensorPlugin ---- \(message)")
          }
      }

      // MARK: - Stream Handler Methods
      public func onListen(withArguments arguments: Any?,
                           eventSink events: @escaping FlutterEventSink) -> FlutterError? {

          // Clean up any existing listeners
          cleanup()

          eventSink = events
          lastReportedValue = nil

          // Enable proximity monitoring
          UIDevice.current.isProximityMonitoringEnabled = true
          guard UIDevice.current.isProximityMonitoringEnabled else {
              log("sensor unavailable")
              return nil
          }
          log("sensor available. Starting hybrid monitoring...")

          // PRIMARY: Set up notification-based detection
          setupNotificationListener()

          // BACKUP: Start intelligent polling
          startIntelligentPolling()

          // Initial state report
          reportCurrentState(source: "initial")

          return nil
      }

      public func onCancel(withArguments arguments: Any?) -> FlutterError? {
          cleanup()
          log("proximity monitoring stopped")
          return nil
      }

      // MARK: - Cleanup
      private func cleanup() {
          // Remove notification observer
          if let observer = notificationObserver {
              NotificationCenter.default.removeObserver(observer)
              notificationObserver = nil
          }

          // Stop timer
          pollTimer?.invalidate()
          pollTimer = nil

          // Clear state
          eventSink = nil
          lastReportedValue = nil
          lastNotificationTime = nil

          // Disable proximity monitoring
          UIDevice.current.isProximityMonitoringEnabled = false
      }

      // MARK: - PRIMARY: Notification-Based Detection
      private func setupNotificationListener() {
          notificationObserver = NotificationCenter.default.addObserver(
              forName: UIDevice.proximityStateDidChangeNotification,
              object: UIDevice.current,
              queue: .main
          ) { [weak self] notification in
              self?.handleProximityNotification(notification)
          }
          log("notification listener registered")
      }

      private func handleProximityNotification(_ notification: Notification) {
          guard let device = notification.object as? UIDevice else { return }

          // Update last notification time
          lastNotificationTime = Date()

          let isNear = device.proximityState
          let brightness = UIScreen.main.brightness

          // Apply brightness correction
          let corrected = correctProximityValue(isNear: isNear, brightness: brightness)

          log("📡 notification: \(isNear ? "NEAR" : "FAR") | brightness: \(String(format: "%.2f", brightness)) | 
  corrected: \(corrected == 1 ? "NEAR" : "FAR")")

          emitIfChanged(corrected, source: "notification")

          // Notifications are working - slow down polling
          adjustPollingInterval(to: normalPollingInterval)
      }

      // MARK: - BACKUP: Intelligent Polling
      private func startIntelligentPolling() {
          // Start with normal polling interval
          pollTimer = Timer.scheduledTimer(
              withTimeInterval: normalPollingInterval,
              repeats: true
          ) { [weak self] _ in
              self?.pollProximity()
          }
          log("intelligent polling started (interval: \(normalPollingInterval)s)")
      }

      private func pollProximity() {
          let now = Date()

          // Check if notifications are still working
          let notificationStale = lastNotificationTime.map { now.timeIntervalSince($0) > notificationTimeoutInterval }
  ?? true

          if notificationStale && pollTimer?.timeInterval != activePollingInterval {
              log("⚠️ notifications stale - switching to active polling")
              adjustPollingInterval(to: activePollingInterval)
          }

          // Read current state
          let isNear = UIDevice.current.proximityState
          let brightness = UIScreen.main.brightness

          // Apply brightness correction
          let corrected = correctProximityValue(isNear: isNear, brightness: brightness)

          // Only log if this is active polling (not backup)
          if notificationStale {
              log("🔄 poll: \(isNear ? "NEAR" : "FAR") | brightness: \(String(format: "%.2f", brightness)) | corrected:
   \(corrected == 1 ? "NEAR" : "FAR")")
          }

          emitIfChanged(corrected, source: notificationStale ? "polling" : "backup-poll")
      }

      private func adjustPollingInterval(to newInterval: TimeInterval) {
          guard pollTimer?.timeInterval != newInterval else { return }

          log("adjusting polling interval: \(newInterval)s")

          pollTimer?.invalidate()
          pollTimer = Timer.scheduledTimer(
              withTimeInterval: newInterval,
              repeats: true
          ) { [weak self] _ in
              self?.pollProximity()
          }
      }

      // MARK: - Correction Logic
      private func correctProximityValue(isNear: Bool, brightness: Double) -> Int8 {
          // If screen is bright but proximity says NEAR → likely false positive (sensor covered but screen on)
          if brightness > brightnessThreshold && isNear {
              return 0  // Force FAR
          }

          // If screen is dark but proximity says FAR → likely false negative (face near but sensor glitch)
          if brightness <= brightnessThreshold && !isNear {
              return 1  // Force NEAR
          }

          // Trust the sensor
          return isNear ? 1 : 0
      }

      // MARK: - State Reporting
      private func reportCurrentState(source: String) {
          let isNear = UIDevice.current.proximityState
          let brightness = UIScreen.main.brightness
          let corrected = correctProximityValue(isNear: isNear, brightness: brightness)

          log("[\(source)] current state: \(corrected == 1 ? "NEAR" : "FAR")")
          emitIfChanged(corrected, source: source)
      }

      private func emitIfChanged(_ value: Int8, source: String) {
          guard value != lastReportedValue else { return }

          lastReportedValue = value
          eventSink?(value)
          log("✅ emitted: \(value == 1 ? "NEAR" : "FAR") (from \(source))")
      }
  }

  //==============================================================================
  public class SwiftProximitySensorPlugin: NSObject, FlutterPlugin
  {
      static var stream_handler: SwiftProximityStreamHandler = SwiftProximityStreamHandler()
      static var eventChannel: FlutterEventChannel = FlutterEventChannel()
      static var methodChannel: FlutterMethodChannel = FlutterMethodChannel()

      public static func register(with registrar: FlutterPluginRegistrar) {
          let eventChannel = FlutterEventChannel(
              name: "proximity_sensor",
              binaryMessenger: registrar.messenger()
          )
          eventChannel.setStreamHandler(stream_handler)

          let methodChannel = FlutterMethodChannel(
              name: "proximity_sensor_enable",
              binaryMessenger: registrar.messenger()
          )

          let instance = SwiftProximitySensorPlugin()
          registrar.addMethodCallDelegate(instance, channel: methodChannel)
      }

      public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
          result(FlutterMethodNotImplemented)
      }
  }
