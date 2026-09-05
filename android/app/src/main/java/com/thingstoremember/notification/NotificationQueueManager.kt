package com.thingstoremember.notification

import android.content.Context
import java.security.MessageDigest
import org.json.JSONArray
import org.json.JSONObject

object NotificationQueueManager {
    private const val PREFS = "nottler_notification_queue"
    private const val QUEUE = "queue"
    private const val PROCESSED = "processed_ids"

    @Synchronized
    fun isAlreadyProcessedOrQueued(context: Context, payload: NotificationPayload): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val processed = jsonArray(prefs.getString(PROCESSED, "[]"))
        for (index in 0 until processed.length()) {
            if (processed.optString(index) == payload.id || processed.optString(index) == fingerprint(payload)) return true
        }
        val queue = jsonArray(prefs.getString(QUEUE, "[]"))
        for (index in 0 until queue.length()) {
            val item = queue.optJSONObject(index) ?: continue
            if (item.optString("id") == payload.id || item.optString("fingerprint") == fingerprint(payload)) return true
        }
        return false
    }

    @Synchronized
    fun enqueue(context: Context, payload: NotificationPayload): Boolean {
        if (isAlreadyProcessedOrQueued(context, payload)) return false
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val queue = jsonArray(prefs.getString(QUEUE, "[]"))
        val item = JSONObject(payload.toMap() as Map<*, *>).apply { put("fingerprint", fingerprint(payload)) }
        queue.put(item)
        prefs.edit().putString(QUEUE, queue.toString()).apply()
        return true
    }

    @Synchronized
    fun popPending(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val queue = jsonArray(prefs.getString(QUEUE, "[]"))
        val result = mutableListOf<Map<String, Any?>>()
        for (index in 0 until queue.length()) {
            val item = queue.optJSONObject(index) ?: continue
            result += mapFromJson(item)
        }
        prefs.edit().remove(QUEUE).apply()
        return result
    }

    @Synchronized
    fun markProcessed(context: Context, payload: NotificationPayload) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val processed = jsonArray(prefs.getString(PROCESSED, "[]"))
        val values = listOf(payload.id, fingerprint(payload))
        values.forEach { value ->
            if ((0 until processed.length()).none { processed.optString(it) == value }) {
                processed.put(value)
            }
        }
        while (processed.length() > 500) processed.remove(0)
        prefs.edit().putString(PROCESSED, processed.toString()).apply()
    }

    @Synchronized
    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(QUEUE)
            .remove(PROCESSED)
            .apply()
    }

    private fun fingerprint(payload: NotificationPayload): String {
        val value = "${payload.packageName}\u0000${payload.senderName.orEmpty()}\u0000${payload.title}\u0000${payload.text}"
        return MessageDigest.getInstance("SHA-256")
            .digest(value.trim().lowercase().replace(Regex("\\s+"), " ").toByteArray())
            .joinToString("") { byte -> "%02x".format(byte) }
    }

    private fun jsonArray(value: String?): JSONArray = try { JSONArray(value ?: "[]") } catch (_: Exception) { JSONArray() }

    private fun mapFromJson(item: JSONObject): Map<String, Any?> = hashMapOf(
        "id" to item.optString("id"),
        "packageName" to item.optString("packageName"),
        "appName" to item.optString("appName"),
        "title" to item.optString("title"),
        "text" to item.optString("text"),
        "subText" to item.optString("subText").takeIf { item.has("subText") },
        "senderName" to item.optString("senderName").takeIf { item.has("senderName") },
        "timestamp" to item.optLong("timestamp"),
    )
}
