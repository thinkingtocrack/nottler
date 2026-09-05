package com.thingstoremember.notification

data class NotificationPayload(
    val id: String,
    val packageName: String,
    val appName: String,
    val title: String,
    val text: String,
    val timestamp: Long,
    val subText: String? = null,
    val senderName: String? = null,
) {
    fun toMap(): HashMap<String, Any?> = hashMapOf(
        "id" to id,
        "packageName" to packageName,
        "appName" to appName,
        "title" to title,
        "text" to text,
        "timestamp" to timestamp,
        "subText" to subText,
        "senderName" to senderName,
    )

    companion object {
        fun fromMap(map: Map<*, *>): NotificationPayload = NotificationPayload(
            id = map["id"]?.toString() ?: "unknown-${System.currentTimeMillis()}",
            packageName = map["packageName"]?.toString() ?: "unknown",
            appName = map["appName"]?.toString() ?: "Unknown app",
            title = map["title"]?.toString() ?: "",
            text = map["text"]?.toString() ?: "",
            timestamp = (map["timestamp"] as? Number)?.toLong() ?: System.currentTimeMillis(),
            subText = map["subText"]?.toString(),
            senderName = map["senderName"]?.toString(),
        )
    }
}
