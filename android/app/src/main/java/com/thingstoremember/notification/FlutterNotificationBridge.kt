package com.thingstoremember.notification

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object FlutterNotificationBridge {
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var eventSink: EventChannel.EventSink? = null

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun emit(event: String, payload: Map<String, Any?>) {
        val eventPayload = HashMap<String, Any?>(payload)
        eventPayload["event"] = event
        mainHandler.post { eventSink?.success(eventPayload) }
    }
}
