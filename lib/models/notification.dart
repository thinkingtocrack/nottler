import 'ai_analysis.dart';

class NotificationPayload {
  const NotificationPayload({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    required this.timestamp,
    this.subText,
    this.senderName,
  });

  final String id;
  final String packageName;
  final String appName;
  final String title;
  final String text;
  final String? subText;
  final String? senderName;
  final int timestamp;

  factory NotificationPayload.fromMap(Map<Object?, Object?> map) {
    return NotificationPayload(
      id: map['id']?.toString() ??
          'unknown-${DateTime.now().microsecondsSinceEpoch}',
      packageName: map['packageName']?.toString() ?? 'unknown',
      appName: map['appName']?.toString() ??
          map['packageName']?.toString() ??
          'Unknown app',
      title: map['title']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      subText: map['subText']?.toString(),
      senderName: map['senderName']?.toString(),
      timestamp: (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'packageName': packageName,
        'appName': appName,
        'title': title,
        'text': text,
        if (subText != null) 'subText': subText,
        if (senderName != null) 'senderName': senderName,
        'timestamp': timestamp,
      };
}

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.payload,
    required this.processed,
    required this.actionTaken,
    required this.category,
    required this.categoryConfidence,
    required this.importance,
    required this.aiProcessed,
    required this.aiModelVersion,
    this.embedding,
    this.summary,
    this.aiProcessingError,
    this.memoryItemId,
    this.contentFingerprint,
  });

  final String id;
  final NotificationPayload payload;
  final bool processed;
  final String actionTaken;
  final NotificationCategory category;
  final double categoryConfidence;
  final int importance;
  final List<double>? embedding;
  final bool aiProcessed;
  final String aiModelVersion;
  final String? summary;
  final String? aiProcessingError;
  final String? memoryItemId;
  final String? contentFingerprint;

  factory NotificationRecord.fromMap(Map<String, Object?> map) {
    final embeddingValue = map['embedding']?.toString();
    return NotificationRecord(
      id: map['id']?.toString() ?? '',
      payload: NotificationPayload(
        id: map['id']?.toString() ?? '',
        packageName: map['package_name']?.toString() ?? '',
        appName: map['app_name']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        text: map['text']?.toString() ?? '',
        subText: map['sub_text']?.toString(),
        senderName: map['sender_name']?.toString(),
        timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      ),
      processed: (map['processed'] as num?)?.toInt() == 1,
      actionTaken: map['action_taken']?.toString() ?? 'IGNORE',
      category: NotificationCategoryX.fromString(map['category']?.toString()),
      categoryConfidence: (map['category_confidence'] as num?)?.toDouble() ?? 0,
      importance: (map['importance'] as num?)?.toInt() ?? 0,
      embedding: embeddingValue == null || embeddingValue.isEmpty
          ? null
          : embeddingValue
              .split(',')
              .map((value) => double.tryParse(value) ?? 0)
              .toList(),
      aiProcessed: (map['ai_processed'] as num?)?.toInt() == 1,
      aiModelVersion: map['ai_model_version']?.toString() ?? 'unknown',
      summary: map['summary']?.toString(),
      aiProcessingError: map['ai_processing_error']?.toString(),
      memoryItemId: map['memory_item_id']?.toString(),
      contentFingerprint: map['content_fingerprint']?.toString(),
    );
  }

  Map<String, Object?> toDatabaseMap() => {
        'id': id,
        'package_name': payload.packageName,
        'app_name': payload.appName,
        'title': payload.title,
        'text': payload.text,
        'sub_text': payload.subText,
        'sender_name': payload.senderName,
        'timestamp': payload.timestamp,
        'processed': processed ? 1 : 0,
        'action_taken': actionTaken,
        'category': category.name,
        'category_confidence': categoryConfidence,
        'importance': importance,
        'embedding': embedding?.join(','),
        'ai_processed': aiProcessed ? 1 : 0,
        'ai_model_version': aiModelVersion,
        'summary': summary,
        'ai_processing_error': aiProcessingError,
        'memory_item_id': memoryItemId,
        'content_fingerprint': contentFingerprint,
      };
}
