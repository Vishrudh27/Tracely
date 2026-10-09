package com.example.habit_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat

/// Handles the mini rectangle's two actions: the OS decline/hang-up icon
/// (no extra "action" extra set) and "Will Complete" (acknowledgement only
/// — cancel + stop ring, no habit/task completion write, matches the
/// full-screen ring screen's own Will Complete button).
class CallAlarmActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        NotificationManagerCompat.from(context).cancel(id)
        AlarmRingtonePlayer.stop()
    }
}
