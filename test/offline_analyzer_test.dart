import 'package:flutter_test/flutter_test.dart';

import 'package:nottler/app_controller.dart';
import 'package:nottler/ai/offline_analyzer.dart';
import 'package:nottler/models/ai_analysis.dart';
import 'package:nottler/models/notification.dart';

NotificationPayload notification({
  required String title,
  required String text,
}) {
  return NotificationPayload(
    id: 'test-1',
    packageName: 'com.example.test',
    appName: 'Test app',
    title: title,
    text: text,
    timestamp: 1,
  );
}

void main() {
  test('classifies sensitive notification categories locally', () {
    final otp = OfflineAnalyzer.analyze(
      notification(title: 'Verification code', text: 'OTP 123456'),
    );
    final banking = OfflineAnalyzer.analyze(
      notification(title: 'SBI alert', text: 'Your account was debited'),
    );

    expect(otp.category, NotificationCategory.otp);
    expect(otp.importance, lessThan(50));
    expect(banking.category, NotificationCategory.banking);
    expect(banking.confidence, greaterThan(0.7));
  });

  test('embedding is deterministic and normalized', () {
    final first = OfflineAnalyzer.embed('Parcel delivered to reception');
    final second = OfflineAnalyzer.embed('Parcel delivered to reception');
    final norm = first.fold<double>(
      0,
      (sum, value) => sum + value * value,
    );

    expect(first, second);
    expect(first, hasLength(128));
    expect(norm, closeTo(1, 0.000001));
  });

  test('actionable notifications become memory items', () {
    final payload = notification(
      title: 'Delivery due tomorrow',
      text: 'Your parcel is out for delivery',
    );
    final analysis = OfflineAnalyzer.analyze(payload);
    final item = OfflineAnalyzer.toMemoryItem(payload, analysis);

    expect(analysis.category, NotificationCategory.delivery);
    expect(item, isNotNull);
    expect(item!.date, isNotNull);
    expect(item.status, 'active');
  });

  test('notification fingerprint ignores casing and repeated whitespace', () {
    final original = notification(
      title: 'SBI payment due',
      text: 'Pay your electricity bill tomorrow',
    );
    final repeated = NotificationPayload(
      id: 'new-id',
      packageName: original.packageName,
      appName: original.appName,
      title: '  sbi   PAYMENT due ',
      text: 'Pay your   electricity bill tomorrow ',
      timestamp: 2,
    );

    expect(
      AppController.notificationFingerprint(repeated),
      AppController.notificationFingerprint(original),
    );
  });
}
