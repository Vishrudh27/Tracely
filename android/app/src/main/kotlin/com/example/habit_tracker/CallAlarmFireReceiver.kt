package com.example.habit_tracker

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat
import java.util.Calendar

class CallAlarmFireReceiver : BroadcastReceiver() {

    companion object {
        // Bumped v1 -> v2: NotificationChannel is immutable once created, so
        // any device that already has v1 installed keeps v1's old
        // sound/vibration settings forever regardless of code changes here.
        const val CALL_CHANNEL_ID = "call_reminders_native_v2"
        private const val TAG = "CallAlarmFireReceiver"

        // Green, not Tracely's brand brown — this tints the mini rectangle's
        // custom "Will Complete" action pill (and the avatar accent ring);
        // the OS-drawn red Hang up pill is fixed by the platform regardless
        // of this value. Not `const`: `.toInt()` on a literal isn't
        // const-foldable to the Kotlin compiler even though it's trivial.
        private val BRAND_COLOR = 0xFF6B9E5E.toInt()

        fun createNotificationChannelIfNeeded(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (manager.getNotificationChannel(CALL_CHANNEL_ID) == null) {
                    val channel = NotificationChannel(
                        CALL_CHANNEL_ID,
                        "Call Reminders",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "Incoming call style notifications for habits and tasks"
                        // Silent: AlarmRingtonePlayer owns the looping
                        // ringtone + vibration directly, started the instant
                        // the notification posts. A channel sound/vibration
                        // here too would double it up.
                        setSound(null, null)
                        enableVibration(false)
                        lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                    }
                    manager.createNotificationChannel(channel)
                }
            }
        }

        fun calculateNextTriggerMillis(
            nowMillis: Long,
            hour: Int,
            minute: Int,
            recurrenceDays: IntArray
        ): Long {
            val now = Calendar.getInstance().apply { timeInMillis = nowMillis }
            val calendarDays = recurrenceDays.map { toCalendarDay(it) }.toSet()

            val candidate = Calendar.getInstance().apply {
                timeInMillis = nowMillis
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            if (!candidate.after(now)) {
                candidate.add(Calendar.DAY_OF_YEAR, 1)
            }

            for (i in 0 until 7) {
                if (calendarDays.contains(candidate.get(Calendar.DAY_OF_WEEK))) {
                    return candidate.timeInMillis
                }
                candidate.add(Calendar.DAY_OF_YEAR, 1)
            }
            return candidate.timeInMillis
        }

        private fun toCalendarDay(w: Int): Int {
            return when (w) {
                1 -> Calendar.MONDAY
                2 -> Calendar.TUESDAY
                3 -> Calendar.WEDNESDAY
                4 -> Calendar.THURSDAY
                5 -> Calendar.FRIDAY
                6 -> Calendar.SATURDAY
                7 -> Calendar.SUNDAY
                else -> Calendar.MONDAY
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "onReceive fired at ${System.currentTimeMillis()}")
        val id = intent.getIntExtra("id", 0)
        val type = intent.getStringExtra("type") ?: "habit_alarm"
        val title = intent.getStringExtra("title") ?: "Reminder"
        val subtitle = intent.getStringExtra("subtitle") ?: "Time for your activity"
        val hour = intent.getIntExtra("hour", 8)
        val minute = intent.getIntExtra("minute", 30)
        val recurrenceDays = intent.getIntArrayExtra("recurrenceDays")

        createNotificationChannelIfNeeded(context)

        // The real app logo for the avatar — the status-bar icon below stays
        // the monochrome glyph (Android forces that one to a flat silhouette
        // regardless), but the Person avatar renders full color.
        val person = Person.Builder()
            .setName(title)
            .setIcon(IconCompat.createWithResource(context, R.mipmap.ic_launcher))
            .build()

        val answerIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.tracely.OPEN_ALARM_RING"
            putExtra("type", type)
            putExtra("id", id)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val answerPendingIntent = PendingIntent.getActivity(
            context,
            id,
            answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val declineIntent = Intent(context, CallAlarmActionReceiver::class.java).apply {
            putExtra("action", "DECLINE")
            putExtra("id", id)
            putExtra("type", type)
        }
        val declinePendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val willCompleteIntent = Intent(context, CallAlarmActionReceiver::class.java).apply {
            putExtra("id", id)
        }
        val willCompletePendingIntent = PendingIntent.getBroadcast(
            context,
            id + 1_000_000,
            willCompleteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // forOngoingCall renders ONE round action (OS-styled red hang-up),
        // not forIncomingCall's green answer + red decline pair — the user
        // doesn't want a green "answer" icon at all. Tapping the banner/card
        // body itself (setContentIntent below) is how you "answer" now.
        val callStyle = NotificationCompat.CallStyle.forOngoingCall(
            person,
            declinePendingIntent
        )

        val notification = NotificationCompat.Builder(context, CALL_CHANNEL_ID)
            .setStyle(callStyle)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setSmallIcon(R.drawable.ic_notification_call)
            .setColor(BRAND_COLOR)
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setContentIntent(answerPendingIntent)
            .setFullScreenIntent(answerPendingIntent, true)
            .setOngoing(true)
            .setAutoCancel(false)
            // Action icon is green in the drawable itself — Android doesn't
            // let a Notification action set a custom TEXT color, only an
            // icon, and some OEMs still force-tint that icon to a system
            // color regardless. Label text may not render green on every
            // device even though the icon does.
            .addAction(R.drawable.ic_notification_check, "Will Complete", willCompletePendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(id, notification)
            // Ringtone + vibration start now, at the banner, not when the
            // user later taps into the full-screen ring screen — real calls
            // ring before you look at the phone.
            AlarmRingtonePlayer.start(context)
        } catch (e: SecurityException) {
            Log.e(TAG, "Notification permission missing", e)
        }

        // Re-arm for next recurrence if recurring habit
        if (recurrenceDays != null && recurrenceDays.isNotEmpty()) {
            val nextMillis = calculateNextTriggerMillis(
                System.currentTimeMillis(),
                hour,
                minute,
                recurrenceDays
            )
            rearmNextOccurrence(context, id, type, title, subtitle, hour, minute, recurrenceDays, nextMillis)
        }
    }

    private fun rearmNextOccurrence(
        context: Context,
        id: Int,
        type: String,
        title: String,
        subtitle: String,
        hour: Int,
        minute: Int,
        recurrenceDays: IntArray,
        nextMillis: Long
    ) {
        val intent = Intent(context, CallAlarmFireReceiver::class.java).apply {
            putExtra("id", id)
            putExtra("type", type)
            putExtra("title", title)
            putExtra("subtitle", subtitle)
            putExtra("triggerAtMillis", nextMillis)
            putExtra("hour", hour)
            putExtra("minute", minute)
            putExtra("recurrenceDays", recurrenceDays)
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
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMillis, firePendingIntent)
            } else {
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(nextMillis, showPendingIntent),
                    firePendingIntent
                )
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Exact alarm permission missing on re-arm", e)
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMillis, firePendingIntent)
        }
    }
}
