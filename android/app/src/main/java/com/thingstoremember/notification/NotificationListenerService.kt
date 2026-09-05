package com.thingstoremember.notification

import android.app.Notification
import android.content.pm.PackageManager
import android.os.Bundle
import android.service.notification.NotificationListenerService as AndroidNotificationListenerService
import android.service.notification.StatusBarNotification
import com.thingstoremember.ai.NotificationAiEngine

class NotificationListenerService : AndroidNotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()

        // Android does not replay notifications that were already visible when
        // notification access was enabled. Seed the same queue with the active
        // notifications so they are not lost on the first connection.
        activeNotifications.orEmpty().forEach(::onNotificationPosted)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null || sbn.packageName == packageName) return
        val extras: Bundle = sbn.notification.extras ?: Bundle()
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        if (title.isBlank() && text.isBlank()) return

        val appName = try {
            val info = packageManager.getApplicationInfo(sbn.packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            sbn.packageName
        }
        val payload = NotificationPayload(
            id = "${sbn.packageName}:${sbn.id}:${sbn.postTime}",
            packageName = sbn.packageName,
            appName = appName,
            title = title,
            text = text,
            subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString(),
            senderName = extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString(),
            timestamp = sbn.postTime,
        )
        if (!NotificationQueueManager.enqueue(applicationContext, payload)) return

        // The listener returns immediately. LiteRT work runs on a single reused
        // executor so a burst cannot block Android's notification callback.
        FlutterNotificationBridge.emit("notification", payload.toMap())
        NotificationAiEngine.analyze(applicationContext, payload) { analysis ->
            val event = HashMap<String, Any?>(payload.toMap())
            event.putAll(analysis)
            FlutterNotificationBridge.emit("notificationAnalyzed", event)
        }
    }
}
