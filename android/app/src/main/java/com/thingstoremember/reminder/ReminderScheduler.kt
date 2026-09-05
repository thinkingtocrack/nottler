package com.thingstoremember.reminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object ReminderScheduler {
    private const val PREFS = "nottler_reminders"
    private const val IDS = "scheduled_ids"
    private const val ACTION_REMIND = "com.thingstoremember.REMIND"

    fun schedule(context: Context, id: String, title: String, body: String, at: Long) {
        if (at <= System.currentTimeMillis()) return
        persist(context, id, title, body, at)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = pendingIntent(context, id, title, body)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, at, pendingIntent)
        }
    }

    fun cancel(context: Context, id: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent(context, id, "", ""))
        remove(context, id)
    }

    fun cancelAll(context: Context) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        preferences.getStringSet(IDS, emptySet()).orEmpty().forEach { id ->
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent(context, id, "", ""))
        }
        preferences.edit().clear().apply()
    }

    fun restore(context: Context) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        preferences.getStringSet(IDS, emptySet()).orEmpty().toList().forEach { id ->
            val at = preferences.getLong(timeKey(id), 0L)
            if (at > System.currentTimeMillis()) {
                schedule(
                    context,
                    id,
                    preferences.getString(titleKey(id), "Reminder") ?: "Reminder",
                    preferences.getString(bodyKey(id), "") ?: "",
                    at,
                )
            } else {
                remove(context, id)
            }
        }
    }

    fun consume(context: Context, id: String) {
        remove(context, id)
    }

    private fun persist(context: Context, id: String, title: String, body: String, at: Long) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = preferences.getStringSet(IDS, emptySet()).orEmpty().toMutableSet()
        ids += id
        preferences.edit()
            .putStringSet(IDS, ids)
            .putString(titleKey(id), title)
            .putString(bodyKey(id), body)
            .putLong(timeKey(id), at)
            .apply()
    }

    private fun remove(context: Context, id: String) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = preferences.getStringSet(IDS, emptySet()).orEmpty().toMutableSet()
        ids -= id
        preferences.edit()
            .putStringSet(IDS, ids)
            .remove(titleKey(id))
            .remove(bodyKey(id))
            .remove(timeKey(id))
            .apply()
    }

    private fun pendingIntent(context: Context, id: String, title: String, body: String): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ACTION_REMIND
            putExtra("id", id)
            putExtra("title", title)
            putExtra("body", body)
        }
        return PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun titleKey(id: String) = "title:$id"
    private fun bodyKey(id: String) = "body:$id"
    private fun timeKey(id: String) = "time:$id"
}
