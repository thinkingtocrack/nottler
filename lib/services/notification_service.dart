import 'dart:async';

import 'package:flutter/services.dart';

import '../models/ai_analysis.dart';
import '../models/notification.dart';

class NotificationEvent {
  const NotificationEvent({required this.payload, this.analysis});

  final NotificationPayload payload;
  final AIAnalysis? analysis;

  factory NotificationEvent.fromMap(Map<Object?, Object?> map) =>
      NotificationEvent(
        payload: NotificationPayload.fromMap(map),
        analysis: map['event'] == 'notificationAnalyzed'
            ? AIAnalysis.fromMap(map)
            : null,
      );
}

class NotificationService {
  static const _channel = MethodChannel('com.thingstoremember/notifications');
  static const _events =
      EventChannel('com.thingstoremember/notifications/events');

  Stream<NotificationEvent> get events async* {
    await for (final event in _events.receiveBroadcastStream()) {
      if (event is Map) {
        yield NotificationEvent.fromMap(Map<Object?, Object?>.from(event));
      }
    }
  }

  Future<List<NotificationPayload>> popPendingNotifications() async {
    try {
      final result =
          await _channel.invokeMethod<List<Object?>>('popPendingNotifications');
      return (result ?? const [])
          .whereType<Map>()
          .map((item) =>
              NotificationPayload.fromMap(Map<Object?, Object?>.from(item)))
          .toList();
    } on PlatformException {
      return const [];
    }
  }

  Future<bool> isAccessGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isNotificationAccessGranted') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openAccessSettings() async {
    await _channel.invokeMethod<void>('openNotificationAccessSettings');
  }

  Future<void> markProcessed(NotificationPayload payload) async {
    try {
      await _channel.invokeMethod<void>(
          'markNotificationProcessed', payload.toMap());
    } on PlatformException {
      // Native queue persistence is best effort; the SQLite id remains authoritative.
    }
  }

  Future<void> clearQueue() async {
    try {
      await _channel.invokeMethod<void>('clearNotificationQueue');
    } on PlatformException {
      // Best effort cleanup when Android is unavailable.
    }
  }
}
