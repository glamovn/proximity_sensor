package dev.jeremyko.proximity_sensor

import android.annotation.SuppressLint
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import io.flutter.plugin.common.EventChannel

class ProximityStreamHandler(
    private val applicationContext: Context,
) : EventChannel.StreamHandler, SensorEventListener {

    private var eventSink: EventChannel.EventSink? = null
    private var sensorManager: SensorManager? = null
    private var proximitySensor: Sensor? = null

    private var powerManager: PowerManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var enableScreenOff: Boolean = false
    private var isListening: Boolean = false

    companion object {
        private const val TAG = "ProximityStreamHandler"
    }

    @SuppressLint("WakelockTimeout")
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "onListen called")
        eventSink = events

        if (sensorManager == null) {
            sensorManager =
                applicationContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        }

        if (proximitySensor == null) {
            proximitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        }

        if (proximitySensor == null) {
            Log.w(TAG, "No proximity sensor available on this device")
            return
        }

        if (powerManager == null) {
            powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
        }

        registerSensorListener()
        updateWakeLockState()
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "onCancel called")
        release()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val distance = event?.values?.get(0)?.toInt()
        if (distance != null) {
            val state = if (distance > 0) 0 else 1
            Log.d(TAG, "Proximity sensor changed → $state")
            eventSink?.success(state)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // no-op
    }

    fun onResume() {
        Log.d(TAG, "onResume called")
        if (eventSink != null && !isListening) {
            registerSensorListener()
            updateWakeLockState()
        }
    }

    fun release() {
        Log.d(TAG, "release called → unregistering sensor + releasing wakelock")
        unregisterSensorListener()
        releaseWakeLock()
        eventSink = null
    }

    fun setScreenOffEnabled(enabled: Boolean) {
        Log.d(TAG, "setScreenOffEnabled($enabled)")
        enableScreenOff = enabled
        updateWakeLockState()
    }

    @SuppressLint("WakelockTimeout")
    private fun updateWakeLockState() {
        if (enableScreenOff && isListening && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            if (wakeLock == null) {
                wakeLock = powerManager?.newWakeLock(
                    PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
                    "dev.jeremyko.proximity_sensor:lock"
                )
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire()
                Log.d(TAG, "WakeLock acquired")
            }
        } else {
            releaseWakeLock()
        }
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
            Log.d(TAG, "WakeLock released")
        }
    }

    private fun registerSensorListener() {
        if (!isListening && proximitySensor != null) {
            val registered = sensorManager?.registerListener(
                this,
                proximitySensor,
                SensorManager.SENSOR_DELAY_NORMAL
            )
            if (registered == true) {
                isListening = true
                Log.d(TAG, "Proximity sensor listener registered")
            } else {
                Log.e(TAG, "Failed to register proximity sensor listener")
            }
        }
    }

    private fun unregisterSensorListener() {
        if (isListening) {
            sensorManager?.unregisterListener(this, proximitySensor)
            isListening = false
            Log.d(TAG, "Proximity sensor listener unregistered")
        }
    }
}
