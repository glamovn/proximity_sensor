import Flutter
import UIKit
import CallKit

//==============================================================================
public class SwiftProximityStreamHandler : NSObject,FlutterStreamHandler
{

    private var eventSink: FlutterEventSink?
    private var lastReportedValue: Int8?
    private var timer: Timer?
    private var lastNotificationDate: Date?
    private let timerInterval: TimeInterval = 1.0 // 1-second polling interval
    private let notificationTimeout: TimeInterval = 2.0 // 2-second timeout
    private var enableTimer = true;
    
    private var isCallActive: Bool = false
    private let callObserver = CXCallObserver()
    
    public override init() {
        super.init()
        callObserver.setDelegate(self, queue: nil)
    }
    
    public func onListen(withArguments arguments: Any?,
                         eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        
        // Apple's  weird way:
        // https://developer.apple.com/documentation/uikit/uidevice/isproximitymonitoringenabled
        // To determine if proximity monitoring is available, attempt to enable it. 
        // If the value of the isProximityMonitoringEnabled property remains false, 
        // proximity monitoring isn’t available.
        UIDevice.current.isProximityMonitoringEnabled = true
        if (UIDevice.current.isProximityMonitoringEnabled == false) {
            print("ProximitySensorPlugin ---- sensor unavailable.")
            return nil
        }
        print("ProximitySensorPlugin ---- sensor available. Listening for state changes...")
        
        // Register for proximity state change notifications
         NotificationCenter.default.addObserver(
            self,
            selector: #selector(proximityStateDidChange),
            name: UIDevice.proximityStateDidChangeNotification,
            object: nil
         )
        
        // Start polling every 1 second
        enableTimer = true
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.enableTimer else { return }
            self.checkProximityState()
        }
        updateShadowingState()
        return nil
    }
}

//==============================================================================
public class SwiftProximitySensorPlugin: NSObject, FlutterPlugin

{
    static var stream_handler:SwiftProximityStreamHandler = SwiftProximityStreamHandler()
    static var eventChannel:FlutterEventChannel = FlutterEventChannel()
    static var methodChannel:FlutterMethodChannel = FlutterMethodChannel()

    public static func register(with registrar: FlutterPluginRegistrar)    {
        let eventChannel = FlutterEventChannel.init(name: "proximity_sensor", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(stream_handler)
        let methodChannel = FlutterMethodChannel(name: "proximity_sensor_enable", binaryMessenger: registrar.messenger())
        let instance = SwiftProximitySensorPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      result(FlutterMethodNotImplemented)
    }
  }


// MARK: - Call State Observation
extension SwiftProximityStreamHandler: CXCallObserverDelegate {
    
     @objc private func proximityStateDidChange(notification: Notification) {
             guard let device = notification.object as? UIDevice else { return }
             print("ProximitySensorPlugin ---- Receive sensor value change from notification...\(device.proximityState)")
             let isNear = UIDevice.current.proximityState
             let corrected: Int8 = isNear ? 1 : 0
             lastNotificationDate = Date()
             let message = isNear ? "proximity NEAR" : "proximity FAR"
             reportProximityChange(corrected: corrected, message: message)
         }
     
     private func reportProximityChange(corrected: Int8, message: String) {
         guard corrected != lastReportedValue else { return }
         lastReportedValue = corrected
         eventSink?(corrected)
         print("ProximitySensorPlugin ---- \(message)")
     }

     private func checkProximityState() {
             let now = Date()
             let isNear: Bool
             // Check if the last notification is stale (older than 2 seconds)
             if let lastDate = lastNotificationDate, now.timeIntervalSince(lastDate) < notificationTimeout {
                 // Notification is recent; no need to read directly
                 return
             }

             isNear = UIDevice.current.proximityState
             let brightness = UIScreen.main.brightness
             var corrected: Int8 = isNear ? 1 : 0
             let message: String
         
             // Determine corrected proximity state based on brightness
             if brightness > 0.1 && isNear {
                 corrected = 0
                 message = "bright screen but proximity NEAR → forcing FAR"
             } else if brightness <= 0.1 && !isNear {
                 corrected = 1
                 message = "dark screen but proximity FAR → forcing NEAR"
             } else {
                 corrected = isNear ? 1 : 0
                 message = isNear ? "proximity NEAR" : "proximity FAR"
             }
             reportProximityChange(corrected: corrected, message: message)
         }
         
     public func onCancel(withArguments arguments: Any?) -> FlutterError? {
             timer?.invalidate()
             timer = nil
             NotificationCenter.default.removeObserver(self)
             UIDevice.current.isProximityMonitoringEnabled = false
             lastNotificationDate = nil
             lastReportedValue = nil
             return nil
         }
    
    public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        let isAppInForeground = UIApplication.shared.applicationState == .active
        let isCallActive = !call.hasEnded && (call.isOutgoing || call.hasConnected || !call.hasConnected)
        enableTimer = isCallActive && !isAppInForeground
    }
}
