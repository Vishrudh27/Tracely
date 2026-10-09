package com.example.habit_tracker

import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/// Owns the continuous ringtone + vibration for an active call-reminder
/// alarm. Started the instant the notification is posted (so the heads-up
/// banner on the home screen rings, not just vibrates) and kept running
/// unchanged when the user taps into the full-screen ring screen — only
/// stopped by an explicit action (Mark Done / Snooze / Dismiss / Decline),
/// wherever that action is handled (Flutter or a native notification button).
/// A singleton object, not a class, because BroadcastReceivers are
/// short-lived and can't hold the Ringtone/Vibrator across calls.
object AlarmRingtonePlayer {
    private const val TAG = "AlarmRingtonePlayer"
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null

    private val vibrationPattern = longArrayOf(0, 700, 500)

    @Synchronized
    fun start(context: Context) {
        if (ringtone != null) return // already ringing for this alarm

        try {
            val ringtoneUri = RingtoneManager.getActualDefaultRingtoneUri(
                context,
                RingtoneManager.TYPE_RINGTONE
            )
            if (ringtoneUri != null) {
                // android.media.Ringtone, not a raw MediaPlayer: it's the
                // system's own class for this exact job and resolves the
                // content:// ringtone URI correctly — raw MediaPlayer.
                // setDataSource on this URI throws "status=0x80000000" on
                // real devices.
                val r = RingtoneManager.getRingtone(context, ringtoneUri)
                if (r != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        r.audioAttributes = AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                        r.isLooping = true
                    } else {
                        @Suppress("DEPRECATION")
                        r.streamType = android.media.AudioManager.STREAM_ALARM
                    }
                    r.play()
                    ringtone = r
                    Log.i(TAG, "Ringtone started: $ringtoneUri")
                } else {
                    Log.e(TAG, "RingtoneManager.getRingtone returned null")
                }
            } else {
                Log.e(TAG, "No default ringtone URI found")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start ringtone", e)
        }

        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                manager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            val effect = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                VibrationEffect.createWaveform(vibrationPattern, 1)
            } else {
                null
            }
            when {
                // VibrationAttributes (API 33+) tags this as an alarm, not
                // an untagged background buzz — some OEM power/haptics
                // policies silently drop unattributed vibration fired from
                // a BroadcastReceiver with no foreground UI.
                Build.VERSION.SDK_INT >= 33 && effect != null -> {
                    val attrs = android.os.VibrationAttributes.Builder()
                        .setUsage(android.os.VibrationAttributes.USAGE_ALARM)
                        .build()
                    vibrator?.vibrate(effect, attrs)
                }
                effect != null -> vibrator?.vibrate(effect)
                else -> {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(vibrationPattern, 1)
                }
            }
            Log.i(TAG, "Vibration started, hasVibrator=${vibrator?.hasVibrator()}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start vibration", e)
        }
    }

    /// Volume-button press on the ring screen: stop the ringtone only,
    /// vibration keeps going — matches real incoming-call behavior.
    @Synchronized
    fun silenceRingtone() {
        try {
            ringtone?.apply {
                if (isPlaying) stop()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to silence ringtone", e)
        } finally {
            ringtone = null
        }
    }

    @Synchronized
    fun stop() {
        try {
            ringtone?.apply {
                if (isPlaying) stop()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to stop ringtone", e)
        } finally {
            ringtone = null
        }

        try {
            vibrator?.cancel()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to cancel vibration", e)
        } finally {
            vibrator = null
        }
    }
}
