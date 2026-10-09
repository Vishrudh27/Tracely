package com.example.habit_tracker

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var methodChannel: MethodChannel? = null

    // True only between the ring screen opening and the user acting on it
    // (clearAlarmLockFlags). Gates the volume-button silence below so it
    // doesn't swallow volume keys during normal app use.
    private var alarmRingActive = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CallAlarmChannel.CHANNEL_NAME)
        channel.setMethodCallHandler(CallAlarmChannel(this))
        methodChannel = channel
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAlarmIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAlarmIntent(intent)
    }

    private fun handleAlarmIntent(intent: Intent?) {
        if (intent?.action == "com.tracely.OPEN_ALARM_RING") {
            val type = intent.getStringExtra("type") ?: "habit_alarm"
            val id = intent.getIntExtra("id", 0)

            if (id != 0) {
                NotificationManagerCompat.from(this).cancel(id)

                // Only while the ring screen is actually up — cleared in
                // clearAlarmLockFlags() the moment the user acts on it
                // (Mark Done / Snooze / Dismiss), so every OTHER screen
                // (dashboard included) never draws over the lock screen.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    setShowWhenLocked(true)
                    setTurnScreenOn(true)
                }
                alarmRingActive = true

                CallAlarmChannel.pendingAlarmOpen = mapOf(
                    "type" to type,
                    "id" to id
                )
                // Covers the app-already-running case: Dart's cold-start
                // getPendingAlarmOpen() poll (in ReminderService.initialize())
                // only ever runs once, on the very first launch, so a warm
                // MainActivity reused via onNewIntent needs this proactive
                // push instead or the pending open is never consumed.
                methodChannel?.invokeMethod(
                    "onAlarmIntentReceived",
                    mapOf("type" to type, "id" to id)
                )
            }
        }
    }

    /// Called from CallAlarmChannel once the user has acted on the ring
    /// screen (Mark Done / Snooze / Dismiss) — reverts the Activity to
    /// normal behavior so it stops being able to draw over the lock screen.
    fun clearAlarmLockFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        }
        alarmRingActive = false
    }

    // Real-call behavior: volume button silences the ringtone, vibration
    // keeps going, until Mark Done / Snooze / Dismiss. Power button can't
    // be hooked this way — KEYCODE_POWER is reserved by the system and
    // only delivered to apps holding the Telecom/Dialer role.
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (alarmRingActive &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            AlarmRingtonePlayer.silenceRingtone()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }
}
