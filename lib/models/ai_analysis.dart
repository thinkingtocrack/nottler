enum NotificationCategory {
  otp,
  finance,
  banking,
  messaging,
  social,
  shopping,
  delivery,
  work,
  travel,
  system,
  promotion,
  other,
}

extension NotificationCategoryX on NotificationCategory {
  String get label {
    switch (this) {
      case NotificationCategory.otp:
        return 'OTP';
      case NotificationCategory.finance:
        return 'Finance';
      case NotificationCategory.banking:
        return 'Banking';
      case NotificationCategory.messaging:
        return 'Messaging';
      case NotificationCategory.social:
        return 'Social';
      case NotificationCategory.shopping:
        return 'Shopping';
      case NotificationCategory.delivery:
        return 'Delivery';
      case NotificationCategory.work:
        return 'Work';
      case NotificationCategory.travel:
        return 'Travel';
      case NotificationCategory.system:
        return 'System';
      case NotificationCategory.promotion:
        return 'Promotion';
      case NotificationCategory.other:
        return 'Other';
    }
  }

  static NotificationCategory fromString(String? value) {
    return NotificationCategory.values.firstWhere(
      (category) => category.name == value?.toLowerCase(),
      orElse: () => NotificationCategory.other,
    );
  }
}

class AIAnalysis {
  const AIAnalysis({
    required this.category,
    required this.confidence,
    required this.importance,
    required this.embedding,
    required this.aiProcessed,
    required this.modelVersion,
    this.summary,
    this.error,
    this.accelerator,
  });

  final NotificationCategory category;
  final double confidence;
  final int importance;
  final List<double> embedding;
  final bool aiProcessed;
  final String modelVersion;
  final String? summary;
  final String? error;
  final String? accelerator;

  AIAnalysis copyWith({
    NotificationCategory? category,
    int? importance,
    String? summary,
    String? modelVersion,
    String? accelerator,
  }) {
    return AIAnalysis(
      category: category ?? this.category,
      confidence: confidence,
      importance: importance ?? this.importance,
      embedding: embedding,
      aiProcessed: aiProcessed,
      modelVersion: modelVersion ?? this.modelVersion,
      summary: summary ?? this.summary,
      error: error,
      accelerator: accelerator ?? this.accelerator,
    );
  }

  factory AIAnalysis.fromMap(Map<Object?, Object?> map) {
    final rawEmbedding = map['embedding'];
    final embedding = rawEmbedding is List
        ? rawEmbedding.map((value) => (value as num).toDouble()).toList()
        : <double>[];
    return AIAnalysis(
      category: NotificationCategoryX.fromString(map['category']?.toString()),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      importance: (map['importance'] as num?)?.toInt() ?? 0,
      embedding: embedding,
      aiProcessed: map['aiProcessed'] == true || map['ai_processed'] == true,
      modelVersion: map['aiModelVersion']?.toString() ??
          map['modelVersion']?.toString() ??
          'unknown',
      summary: map['summary']?.toString(),
      error: map['aiProcessingError']?.toString() ?? map['error']?.toString(),
      accelerator: map['accelerator']?.toString(),
    );
  }

  Map<String, Object?> toMap() => {
        'category': category.name,
        'confidence': confidence,
        'importance': importance,
        'embedding': embedding,
        'aiProcessed': aiProcessed,
        'aiModelVersion': modelVersion,
        if (summary != null) 'summary': summary,
        if (error != null) 'aiProcessingError': error,
        if (accelerator != null) 'accelerator': accelerator,
      };
}
