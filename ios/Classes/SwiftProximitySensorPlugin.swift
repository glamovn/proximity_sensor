import Flutter
import UIKit
import CallKit

//==============================================================================
public class SwiftProximityStreamHandler : NSObject,FlutterStreamHandler
{

    var eventSink: FlutterEventSink?
    var lastReportedValue: Int8?
    var timer: Timer?
    
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
        
//        notiCenter.addObserver(forName: UIDevice.proximityStateDidChangeNotification,
//                                object: device,
//                                queue: nil,
//                                using : { (notification) in
//                                            if let device = notification.object as? UIDevice {
//                                                // true -> something is near
//                                                let isNear = device.proximityState    
//                                                let onoff:Int8 = isNear ? 1 : 0
//                                                print("📡 ProximitySensorPlugin state changed → \(isNear ? "NEAR" : "FAR") (\(onoff))")
//                                                events(onoff)
//                                            }
//                                        })

        
            // Start polling every 200 ms
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                self?.pollProximityAndBrightness()
            }
        return nil
    }
    
    private func pollProximityAndBrightness() {
        let isNear = UIDevice.current.proximityState
        let brightness = UIScreen.main.brightness
        var corrected: Int8 = isNear ? 1 : 0
        if brightness > 0.1 && isNear {
            corrected = 0
            if corrected == lastReportedValue {
                return
            }
            print("ProximitySensorPlugin  ---- bright screen but proximity NEAR → forcing FAR")
        } else if brightness <= 0.1 && !isNear {
            corrected = 1
            if corrected == lastReportedValue {
                return
            }
            print("ProximitySensorPlugin ---- dark screen but proximity FAR → forcing NEAR")
        }

        if corrected != lastReportedValue {
            lastReportedValue = corrected
            eventSink?(corrected)
            print("ProximitySensorPlugin ---- \(corrected == 1 ? "NEAR" : "FAR")")
        }
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.isProximityMonitoringEnabled = false
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




