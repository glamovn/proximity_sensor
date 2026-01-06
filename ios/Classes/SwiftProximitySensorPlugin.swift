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

      // App lifecycle observers
      private var didEnterBackgroundObserver: NSObjectProtocol?
      private var willEnterForegroundObserver: NSObjectProtocol?

      // Polling backup mechanism
      private var pollTimer: Timer?
      private var isActive: Bool = false

      // Configuration
      private let pollingInterval: TimeInterval = 0.5  // Simple consistent polling

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
          isActive = true

          // Set up app lifecycle observers
          setupLifecycleObservers()

          // Start monitoring
          startProximityMonitoring()

          return nil
      }

      public func onCancel(withArguments arguments: Any?) -> FlutterError? {
          cleanup()
          log("proximity monitoring stopped")
          return nil
      }

      // MARK: - Cleanup
      private func cleanup() {
          isActive = false

          // Remove notification observers
          if let observer = notificationObserver {
              NotificationCenter.default.removeObserver(observer)
              notificationObserver = nil
          }

          if let observer = didEnterBackgroundObserver {
              NotificationCenter.default.removeObserver(observer)
              didEnterBackgroundObserver = nil
          }

          if let observer = willEnterForegroundObserver {
              NotificationCenter.default.removeObserver(observer)
              willEnterForegroundObserver = nil
          }

          // Stop timer
          pollTimer?.invalidate()
          pollTimer = nil

          // Clear state
          eventSink = nil
          lastReportedValue = nil

          // Disable proximity monitoring
          UIDevice.current.isProximityMonitoringEnabled = false
          log("cleanup complete")
      }

      // MARK: - App Lifecycle
      private func setupLifecycleObservers() {
          didEnterBackgroundObserver = NotificationCenter.default.addObserver(
              forName: UIApplication.didEnterBackgroundNotification,
              object: nil,
              queue: .main
          ) { [weak self] _ in
              self?.handleDidEnterBackground()
          }

          willEnterForegroundObserver = NotificationCenter.default.addObserver(
              forName: UIApplication.willEnterForegroundNotification,
              object: nil,
              queue: .main
          ) { [weak self] _ in
              self?.handleWillEnterForeground()
          }
          log("lifecycle observers registered")
      }

      private func handleDidEnterBackground() {
          log("app entered background → pausing proximity monitoring")
          stopProximityMonitoring()
      }

      private func handleWillEnterForeground() {
          log("app entering foreground → resuming proximity monitoring")
          if isActive {
              startProximityMonitoring()
          }
      }

      // MARK: - Proximity Monitoring
      private func startProximityMonitoring() {
          // Enable proximity monitoring
          UIDevice.current.isProximityMonitoringEnabled = true

          guard UIDevice.current.isProximityMonitoringEnabled else {
              log("⚠️ proximity sensor unavailable on this device")
              return
          }
          log("✅ proximity monitoring enabled")

          // Set up notification listener
          setupNotificationListener()

          // Start polling as backup
          startPolling()

          // Report initial state
          reportCurrentState()
      }

      private func stopProximityMonitoring() {
          // Stop polling
          pollTimer?.invalidate()
          pollTimer = nil

          // Remove notification observer
          if let observer = notificationObserver {
              NotificationCenter.default.removeObserver(observer)
              notificationObserver = nil
          }

          // Disable proximity monitoring
          UIDevice.current.isProximityMonitoringEnabled = false
          log("proximity monitoring disabled")
      }

      private func setupNotificationListener() {
          notificationObserver = NotificationCenter.default.addObserver(
              forName: UIDevice.proximityStateDidChangeNotification,
              object: UIDevice.current,
              queue: .main
          ) { [weak self] _ in
              self?.handleProximityChange()
          }
          log("notification listener registered")
      }

      private func handleProximityChange() {
          let value = UIDevice.current.proximityState ? Int8(1) : Int8(0)
          log("📡 proximity notification: \(value == 1 ? "NEAR" : "FAR")")
          emitIfChanged(value)
      }

      private func startPolling() {
          pollTimer = Timer.scheduledTimer(
              withTimeInterval: pollingInterval,
              repeats: true
          ) { [weak self] _ in
              self?.pollProximity()
          }
          log("polling started (interval: \(pollingInterval)s)")
      }

      private func pollProximity() {
          let value = UIDevice.current.proximityState ? Int8(1) : Int8(0)
          emitIfChanged(value)
      }

      private func reportCurrentState() {
          let value = UIDevice.current.proximityState ? Int8(1) : Int8(0)
          log("initial state: \(value == 1 ? "NEAR" : "FAR")")
          emitIfChanged(value)
      }

      private func emitIfChanged(_ value: Int8) {
          guard value != lastReportedValue else { return }

          lastReportedValue = value
          eventSink?(value)
          log("✅ emitted: \(value == 1 ? "NEAR (1)" : "FAR (0)")")
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
