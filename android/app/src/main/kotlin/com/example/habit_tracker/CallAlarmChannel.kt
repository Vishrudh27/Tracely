package com.example.habit_tracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CallAlarmChannel(private val activity: MainActivity) : MethodChannel.MethodCallHandler {

    private val context: Context get() = activity

    companion object {
        const val CHANNEL_NAME = "com.tracely/call_alarm"
        private const val TAG = "CallAlarmChannel"

        @JvmStatic
        var pendingAlarmOpen: Map<String, Any>? = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scheduleCallAlarm" -> {
                try {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        scheduleCallAlarm(args)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Arguments map expected", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in scheduleCallAlarm", e)
                    result.error("SCHEDULE_FAILED", e.message, null)
                }
            }
            "cancelCallAlarm" -> {
                try {
                    val id = (call.argument<Number>("id"))?.toInt()
                    if (id != null) {
                        cancelCallAlarm(id)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing id", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in cancelCallAlarm", e)
                    result.error("CANCEL_FAILED", e.message, null)
                }
            }
            "getPendingAlarmOpen" -> {
                val openData = pendingAlarmOpen
                pendingAlarmOpen = null
                result.success(openData)
            }
            "clearLockScreenFlags" -> {
                activity.clearAlarmLockFlags()
                result.success(true)
            }
            "moveTaskToBack" -> {
                // Ring screen's own exit (Mark Done / Snooze / Dismiss): send
                // the whole task behind whatever was there before (lock
                // screen, home screen, or another app) instead of letting
                // Flutter navigate to the dashboard, which would flash the
                // app's own UI over the lock screen for a frame.
                activity.moveTaskToBack(true)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun scheduleCallAlarm(args: Map<*, *>) {
        val id = (args["id"] as Number).toInt()
        val type = args["type"] as String
        val title = args["title"] as String
        val subtitle = args["subtitle"] as String
        val triggerAtMillis = (args["triggerAtMillis"] as Number).toLong()
        val hour = (args["hour"] as Number).toInt()
        val minute = (args["minute"] as Number).toInt()

        val rawRecurrence = args["recurrenceDays"] as? List<*>
        val recurrenceDays = rawRecurrence?.mapNotNull { (it as? Number)?.toInt() }?.toIntArray()

        val intent = Intent(context, CallAlarmFireReceiver::class.java).apply {
            putExtra("id", id)
            putExtra("type", type)
            putExtra("title", title)
            putExtra("subtitle", subtitle)
            putExtra("triggerAtMillis", triggerAtMillis)
            putExtra("hour", hour)
            putExtra("minute", minute)
            if (recurrenceDays != null) {
                putExtra("recurrenceDays", recurrenceDays)
            }
        }

        val firePendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val showIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.tracely.OPEN_ALARM_RING"
            putExtra("type", type)
            putExtra("id", id)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val showPendingIntent = PendingIntent.getActivity(
            context,
            id,
            showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                // Fallback for missing exact alarm permission
                Log.w(TAG, "Exact alarm permission NOT granted — falling back to inexact for id=$id at $triggerAtMillis")
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    firePendingIntent
                )
            } else {
                Log.i(TAG, "Scheduled exact alarm id=$id type=$type at $triggerAtMillis (now=${System.currentTimeMillis()})")
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent),
                    firePendingIntent
                )
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Exact alarm permission missing; fallback to setAndAllowWhileIdle", e)
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                firePendingIntent
            )
        }
    }

    private fun cancelCallAlarm(id: Int) {
        val intent = Intent(context, CallAlarmFireReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)

        NotificationManagerCompat.from(context).cancel(id)
        AlarmRingtonePlayer.stop()
    }
}
