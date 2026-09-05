import 'package:flutter/services.dart';

class ReminderService {
  static const _channel = MethodChannel('com.thingstoremember/reminders');

  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod<void>('requestReminderPermission');
    } on PlatformException {
      // Older Android versions do not need notification permission.
    }
  }

  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    try {
      await _channel.invokeMethod<void>('scheduleReminder', {
        'id': id,
        'title': title,
        'body': body,
        'at': at.millisecondsSinceEpoch,
      });
    } on PlatformException {
      // The reminder remains visible in the app if Android cannot schedule it.
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _channel.invokeMethod<void>('cancelReminder', {'id': id});
    } on PlatformException {
      // Best effort: a stale local notification is harmless.
    }
  }

  Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod<void>('cancelAllReminders');
    } on PlatformException {
      // Best effort cleanup when the native channel is unavailable.
    }
  }
}
