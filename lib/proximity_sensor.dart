import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'dart:io' show Platform;

/// A Flutter plugin for proximity sensor functionality.
///
/// This plugin provides access to the device's proximity sensor,
/// which detects when an object (like a face or hand) is near the device.
///
/// **Platform Support:**
/// - Android: Full support including automatic screen on/off
/// - iOS: Event stream support only
/// - Web/Desktop: Not supported (returns dummy stream)
///
/// **Usage Example:**
/// ```dart
/// // Simple proximity detection
/// ProximitySensor.events.listen((event) {
///   if (event == 1) {
///     print('Object is NEAR the sensor');
///   } else {
///     print('Object is FAR from the sensor');
///   }
/// });
///
/// // Android: Enable automatic screen off when sensor is covered
/// await ProximitySensor.setProximityScreenOff(true);
///
/// // Later, disable automatic screen off
/// await ProximitySensor.setProximityScreenOff(false);
/// ```
class ProximitySensor {
  static EventChannel _streamChannel = EventChannel('proximity_sensor');
  static MethodChannel _methodChannel =
      MethodChannel('proximity_sensor_enable');

  /// Stream of proximity sensor events.
  ///
  /// **Event Values:**
  /// - `0`: Object is FAR from sensor (not covered)
  /// - `1`: Object is NEAR sensor (covered)
  ///
  /// **Platform Support:**
  /// - Android: ✅ Supported
  /// - iOS: ✅ Supported
  /// - Web/Desktop: ⚠️ Returns dummy stream (no events)
  ///
  /// **Important Notes:**
  /// - Events are delivered continuously while listening
  /// - On Android, sensor automatically pauses when app goes to background
  /// - To prevent screen from turning off, call `setProximityScreenOff(false)`
  ///
  /// **Example:**
  /// ```dart
  /// StreamSubscription? subscription;
  ///
  /// void startListening() {
  ///   subscription = ProximitySensor.events.distinct().listen((event) {
  ///     if (event == 1) {
  ///       print('Sensor covered - object is NEAR');
  ///     } else {
  ///       print('Sensor uncovered - object is FAR');
  ///     }
  ///   });
  /// }
  ///
  /// void stopListening() {
  ///   subscription?.cancel();
  ///   subscription = null;
  /// }
  /// ```
  static Stream<int> get events {
    if (!foundation.kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return _streamChannel.receiveBroadcastStream().map((event) {
        return event;
      });
    } else {
      return Stream.periodic(Duration(hours: 1), (x) => 0); // fake stream...
    }
  }

  /// Controls automatic screen on/off based on proximity sensor (Android only).
  ///
  /// When enabled, the screen will automatically turn off when the proximity
  /// sensor detects an object nearby (like during a phone call).
  ///
  /// **Parameters:**
  /// - `enabled`: `true` to enable automatic screen off, `false` to disable
  ///
  /// **Platform Support:**
  /// - Android: ✅ Supported (API 21+)
  /// - iOS: ❌ Not supported (no-op)
  /// - Web/Desktop: ❌ Not supported (no-op)
  ///
  /// **Important Notes:**
  /// - Must be called BEFORE starting to listen to events for immediate effect
  /// - Can be toggled at runtime to enable/disable screen control
  /// - Screen will return to normal when sensor is no longer covered
  /// - Automatically disabled when app goes to background
  ///
  /// **Typical Usage Pattern:**
  /// ```dart
  /// // Scenario 1: Phone call - enable screen off
  /// await ProximitySensor.setProximityScreenOff(true);
  /// ProximitySensor.events.listen((event) {
  ///   // Handle proximity events during call
  /// });
  ///
  /// // Scenario 2: Simple detection - disable screen off
  /// await ProximitySensor.setProximityScreenOff(false);
  /// ProximitySensor.events.listen((event) {
  ///   // Just detect proximity without screen control
  /// });
  /// ```
  ///
  /// **Common Issue:**
  /// If you see a dark screen when covering the sensor, call:
  /// ```dart
  /// await ProximitySensor.setProximityScreenOff(false);
  /// ```
  static Future<void> setProximityScreenOff(bool enabled) async {
    if (!foundation.kIsWeb && Platform.isAndroid) {
      await _methodChannel
          .invokeMethod<void>('enableProximityScreenOff', <String, dynamic>{
        'enabled': enabled,
      });
    }
  }
}
