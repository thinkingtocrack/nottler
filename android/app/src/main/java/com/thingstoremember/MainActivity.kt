package com.thingstoremember

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.thingstoremember.ai.NotificationAiEngine
import com.thingstoremember.ai.NotificationLlmEngine
import com.thingstoremember.notification.FlutterNotificationBridge
import com.thingstoremember.notification.NotificationPayload
import com.thingstoremember.notification.NotificationQueueManager
import com.thingstoremember.reminder.ReminderScheduler

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.thingstoremember/notifications"
    private val aiChannelName = "com.thingstoremember/ai"
    private val eventsChannelName = "com.thingstoremember/notifications/events"
    private val remindersChannelName = "com.thingstoremember/reminders"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NotificationAiEngine.start(applicationContext)
        NotificationLlmEngine.start(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationAiEngine.start(applicationContext)
        NotificationLlmEngine.start(applicationContext)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventsChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    FlutterNotificationBridge.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    FlutterNotificationBridge.setEventSink(null)
                }
            },
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result -> handleNotificationCall(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, aiChannelName)
            .setMethodCallHandler { call, result -> handleAiCall(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, remindersChannelName)
            .setMethodCallHandler { call, result -> handleReminderCall(call, result) }
    }

    private fun handleNotificationCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isNotificationAccessGranted" -> result.success(isNotificationAccessGranted())
            "openNotificationAccessSettings" -> {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(true)
            }
            "popPendingNotifications" -> result.success(NotificationQueueManager.popPending(applicationContext))
            "markNotificationProcessed" -> {
                val payload = NotificationPayload.fromMap(call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                if (payload.id.isNotBlank()) NotificationQueueManager.markProcessed(applicationContext, payload)
                result.success(true)
            }
            "clearNotificationQueue" -> {
                NotificationQueueManager.clear(applicationContext)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleReminderCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestReminderPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                ) {
                    requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), REMINDER_PERMISSION_REQUEST)
                }
                result.success(true)
            }
            "scheduleReminder" -> {
                val id = call.argument<String>("id")
                val title = call.argument<String>("title")
                val body = call.argument<String>("body")
                val at = call.argument<Long>("at")
                if (id.isNullOrBlank() || title.isNullOrBlank() || at == null) {
                    result.error("INVALID_REMINDER", "A reminder needs an id, title, and schedule time.", null)
                } else {
                    ReminderScheduler.schedule(applicationContext, id, title, body.orEmpty(), at)
                    result.success(true)
                }
            }
            "cancelReminder" -> {
                call.argument<String>("id")?.let { ReminderScheduler.cancel(applicationContext, it) }
                result.success(true)
            }
            "cancelAllReminders" -> {
                ReminderScheduler.cancelAll(applicationContext)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleAiCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "aiStatus" -> {
                val status = HashMap<String, Any?>(NotificationAiEngine.status(applicationContext))
                status.putAll(NotificationLlmEngine.status(applicationContext))
                result.success(status)
            }
            "analyzeNotification" -> {
                val payload = NotificationPayload.fromMap(call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                NotificationAiEngine.analyze(applicationContext, payload) { analysis ->
                    runOnUiThread { result.success(analysis) }
                }
            }
            "embedNotification" -> {
                val text = call.argument<String>("text") ?: ""
                NotificationAiEngine.embed(applicationContext, text) { embedding ->
                    runOnUiThread { result.success(embedding) }
                }
            }
            "summarizeNotification" -> {
                val payload = NotificationPayload.fromMap(call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                NotificationLlmEngine.summarize(applicationContext, payload) { summary ->
                    runOnUiThread { result.success(summary) }
                }
            }
            "downloadLanguageModel" -> {
                NotificationLlmEngine.download(applicationContext) { success, error ->
                    runOnUiThread {
                        if (success) result.success(true)
                        else result.error("MODEL_DOWNLOAD", error ?: "The local language model could not be installed.", null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun isNotificationAccessGranted(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        val component = ComponentName(this, "${packageName}.notification.NotificationListenerService")
        return enabled.split(":").any { TextUtils.equals(it, component.flattenToString()) }
    }

    private companion object {
        const val REMINDER_PERMISSION_REQUEST = 4107
    }
}
