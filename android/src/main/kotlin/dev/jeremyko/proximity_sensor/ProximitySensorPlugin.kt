package dev.jeremyko.proximity_sensor

import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter

class ProximitySensorPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private val TAG = "ProximitySensorPlugin"

  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var streamHandler: ProximityStreamHandler
  private var lifecycle: Lifecycle? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    Log.d(TAG, "onAttachedToEngine")
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "proximity_sensor_enable")
    methodChannel.setMethodCallHandler(this)

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "proximity_sensor")
    streamHandler = ProximityStreamHandler(flutterPluginBinding.applicationContext)
    eventChannel.setStreamHandler(streamHandler)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    Log.d(TAG, "onAttachedToActivity")
    lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)
    lifecycle?.addObserver(object : LifecycleObserver {
      @OnLifecycleEvent(Lifecycle.Event.ON_PAUSE)
      fun onPause() {
        Log.d(TAG, "Lifecycle: ON_PAUSE → releasing proximity sensor")
        streamHandler.release()
      }

      @OnLifecycleEvent(Lifecycle.Event.ON_RESUME)
      fun onResume() {
        Log.d(TAG, "Lifecycle: ON_RESUME → resuming proximity sensor")
        streamHandler.onResume()
      }
    })
  }

  override fun onDetachedFromActivity() {
    Log.d(TAG, "onDetachedFromActivity")
    lifecycle = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    Log.d(TAG, "onReattachedToActivityForConfigChanges")
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    Log.d(TAG, "onDetachedFromActivityForConfigChanges")
    onDetachedFromActivity()
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    Log.d(TAG, "onDetachedFromEngine → disabling proximity sensor")

    streamHandler.setScreenOffEnabled(false)
    streamHandler.release()

    lifecycle = null
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    Log.d(TAG, "onMethodCall: ${call.method}, args=${call.arguments}")
    if (call.method == "enableProximityScreenOff") {
      val enabled: Boolean? = call.argument("enabled")
      if (enabled == null) {
        Log.e(TAG, "enableProximityScreenOff called with null argument")
        result.error("INVALID_ARGUMENTS", "'enabled' cannot be null", null)
      } else {
        Log.d(TAG, "enableProximityScreenOff: enabled = $enabled")
        streamHandler.setScreenOffEnabled(enabled)
        result.success(null)
      }
    } else {
      Log.w(TAG, "Unknown method called: ${call.method}")
      result.notImplemented()
    }
  }
}
