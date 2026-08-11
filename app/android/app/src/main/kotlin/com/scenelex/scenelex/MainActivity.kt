package com.scenelex.scenelex

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PowerModePlugin.register(this, flutterEngine)
    }
}

/** Exposes Android Power Save Mode to Dart (channel `scenelex/power_mode`). */
private class PowerModePlugin(
    private val context: Context,
    private val flutterEngine: FlutterEngine
) {
    companion object {
        fun register(context: Context, flutterEngine: FlutterEngine) {
            val plugin = PowerModePlugin(context, flutterEngine)
            val methodChannel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "scenelex/power_mode"
            )
            methodChannel.setMethodCallHandler { call, result ->
                if (call.method == "isLowPowerEnabled") {
                    result.success(plugin.isPowerSaveMode)
                } else {
                    result.notImplemented()
                }
            }
            val eventChannel = EventChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "scenelex/power_mode/events"
            )
            eventChannel.setStreamHandler(plugin.eventStreamHandler)
        }
    }

    private val powerManager: PowerManager =
        context.getSystemService(Context.POWER_SERVICE) as PowerManager

    private val isPowerSaveMode: Boolean
        get() = powerManager.isPowerSaveMode

    private var eventSink: EventChannel.EventSink? = null

    private val powerSaveModeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == PowerManager.ACTION_POWER_SAVE_MODE_CHANGED) {
                eventSink?.success(powerManager.isPowerSaveMode)
            }
        }
    }

    private val eventStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            events?.success(powerManager.isPowerSaveMode)
            val filter = IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(
                    powerSaveModeReceiver,
                    filter,
                    Context.RECEIVER_NOT_EXPORTED
                )
            } else {
                context.registerReceiver(powerSaveModeReceiver, filter)
            }
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            context.unregisterReceiver(powerSaveModeReceiver)
        }
    }
}
