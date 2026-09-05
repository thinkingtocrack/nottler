import 'dart:math' as math;

import '../models/ai_analysis.dart';
import '../models/memory_item.dart';
import '../models/notification.dart';

class OfflineAnalyzer {
  static AIAnalysis analyze(NotificationPayload notification) {
    final text =
        '${notification.title} ${notification.text} ${notification.subText ?? ''}'
            .trim();
    final lower = text.toLowerCase();
    final category = _category(lower, notification.packageName);
    final confidence = _confidence(category, lower);
    final importance = _importance(category, lower);
    return AIAnalysis(
      category: category,
      confidence: confidence,
      importance: importance,
      embedding: embed(text),
      aiProcessed: true,
      modelVersion: 'offline-feature-v1',
      summary: _summary(category, lower),
      accelerator: 'Dart fallback',
    );
  }

  static List<double> embed(String text) {
    const dimensions = 128;
    final vector = List<double>.filled(dimensions, 0);
    final normalized =
        text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    for (final token in tokens) {
      final index = token.hashCode.abs() % dimensions;
      vector[index] += 1;
      if (token.length > 3) {
        final bigramIndex =
            '${token[0]}${token[1]}'.hashCode.abs() % dimensions;
        vector[bigramIndex] += 0.25;
      }
    }
    final norm =
        math.sqrt(vector.fold<double>(0, (sum, value) => sum + value * value));
    return norm == 0 ? vector : vector.map((value) => value / norm).toList();
  }

  static NotificationCategory _category(String text, String packageName) {
    if (RegExp(
            r'\botp\b|verification code|one time password|security code|do not share')
        .hasMatch(text)) {
      return NotificationCategory.otp;
    }
    if (RegExp(r'bank|upi|sbi|hdfc|icici|axis|debit|credit card|account')
        .hasMatch(text)) {
      return NotificationCategory.banking;
    }
    if (RegExp(r'payment|paid|invoice|bill|salary|refund|transaction|wallet')
        .hasMatch(text)) {
      return NotificationCategory.finance;
    }
    if (RegExp(r'deliver|shipment|parcel|tracking|courier|out for delivery')
        .hasMatch(text)) {
      return NotificationCategory.delivery;
    }
    if (RegExp(r'flight|train|boarding|hotel|booking|reservation|uber|ola')
        .hasMatch(text)) {
      return NotificationCategory.travel;
    }
    if (RegExp(r'meeting|calendar|deadline|work|slack|teams|interview|task')
        .hasMatch(text)) {
      return NotificationCategory.work;
    }
    if (RegExp(r'order|cart|shop|sale|coupon|discount|amazon|flipkart')
        .hasMatch(text)) {
      return RegExp(r'sale|coupon|discount|offer|promo').hasMatch(text)
          ? NotificationCategory.promotion
          : NotificationCategory.shopping;
    }
    if (RegExp(r'whatsapp|telegram|message|chat|sms|signal')
        .hasMatch('$text $packageName')) {
      return NotificationCategory.messaging;
    }
    if (RegExp(r'instagram|facebook|like|comment|follow|social')
        .hasMatch(text)) {
      return NotificationCategory.social;
    }
    if (RegExp(r'update available|battery|system|connected|storage|android')
        .hasMatch(text)) {
      return NotificationCategory.system;
    }
    return NotificationCategory.other;
  }

  static double _confidence(NotificationCategory category, String text) {
    if (category == NotificationCategory.other) {
      return 0.45;
    }
    if (category == NotificationCategory.otp ||
        category == NotificationCategory.promotion) {
      return 0.97;
    }
    return text.length > 18 ? 0.86 : 0.72;
  }

  static int _importance(NotificationCategory category, String text) {
    if (category == NotificationCategory.otp ||
        category == NotificationCategory.promotion) {
      return 15;
    }
    if (RegExp(r'urgent|asap|immediately|overdue|failed|blocked|cancelled')
        .hasMatch(text)) {
      return 95;
    }
    if (category == NotificationCategory.banking ||
        category == NotificationCategory.finance) {
      return 82;
    }
    if (category == NotificationCategory.work ||
        category == NotificationCategory.travel) {
      return 74;
    }
    return 52;
  }

  static String? _summary(NotificationCategory category, String text) {
    switch (category) {
      case NotificationCategory.delivery:
        return 'Delivery update';
      case NotificationCategory.banking:
        return 'Banking notification';
      case NotificationCategory.finance:
        return 'Finance update';
      case NotificationCategory.travel:
        return 'Travel update';
      default:
        return null;
    }
  }

  static MemoryItem? toMemoryItem(
      NotificationPayload notification, AIAnalysis analysis) {
    final actionable = analysis.category != NotificationCategory.otp &&
        analysis.category != NotificationCategory.promotion &&
        analysis.category != NotificationCategory.system &&
        (analysis.importance >= 70 ||
            RegExp(r'due|deadline|meeting|booking|deliver|payment|action required')
                .hasMatch('${notification.title} ${notification.text}'
                    .toLowerCase()));
    if (!actionable) return null;

    final now = DateTime.now();
    final title = notification.title.isEmpty
        ? analysis.category.label
        : notification.title;
    return MemoryItem(
      id: 'memory-${notification.id}',
      title: title,
      description:
          notification.text.isEmpty ? notification.title : notification.text,
      category: analysis.category.label,
      importance: analysis.importance,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      date: _dateForText('${notification.title} ${notification.text}', now),
      time: null,
      responsibleParty: notification.senderName ?? notification.appName,
      sourceApp: notification.appName,
      sourcePackage: notification.packageName,
      sourceText: notification.text,
    );
  }

  static String? _dateForText(String text, DateTime now) {
    final lower = text.toLowerCase();
    if (lower.contains('today')) {
      return _date(now);
    }
    if (lower.contains('tomorrow')) {
      return _date(now.add(const Duration(days: 1)));
    }
    return null;
  }

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
