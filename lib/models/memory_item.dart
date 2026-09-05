class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.importance,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.date,
    this.time,
    this.location,
    this.responsibleParty,
    this.sourceApp,
    this.sourcePackage,
    this.sourceText,
    this.contentFingerprint,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final int importance;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? date;
  final String? time;
  final String? location;
  final String? responsibleParty;
  final String? sourceApp;
  final String? sourcePackage;
  final String? sourceText;
  final String? contentFingerprint;

  factory MemoryItem.fromMap(Map<String, Object?> map) => MemoryItem(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        category: map['category']?.toString() ?? 'Other',
        importance: (map['importance'] as num?)?.toInt() ?? 50,
        status: map['status']?.toString() ?? 'active',
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        date: map['date']?.toString(),
        time: map['time']?.toString(),
        location: map['location']?.toString(),
        responsibleParty: map['responsible_party']?.toString(),
        sourceApp: map['source_app']?.toString(),
        sourcePackage: map['source_package']?.toString(),
        sourceText: map['source_text']?.toString(),
        contentFingerprint: map['content_fingerprint']?.toString(),
      );

  Map<String, Object?> toDatabaseMap() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'importance': importance,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'date': date,
        'time': time,
        'location': location,
        'responsible_party': responsibleParty,
        'source_app': sourceApp,
        'source_package': sourcePackage,
        'source_text': sourceText,
        'content_fingerprint': contentFingerprint,
      };

  MemoryItem withStatus(String nextStatus) => MemoryItem(
        id: id,
        title: title,
        description: description,
        category: category,
        importance: importance,
        status: nextStatus,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        date: date,
        time: time,
        location: location,
        responsibleParty: responsibleParty,
        sourceApp: sourceApp,
        sourcePackage: sourcePackage,
        sourceText: sourceText,
        contentFingerprint: contentFingerprint,
      );

  MemoryItem withContentFingerprint(String fingerprint) => MemoryItem(
        id: id,
        title: title,
        description: description,
        category: category,
        importance: importance,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        date: date,
        time: time,
        location: location,
        responsibleParty: responsibleParty,
        sourceApp: sourceApp,
        sourcePackage: sourcePackage,
        sourceText: sourceText,
        contentFingerprint: fingerprint,
      );
}
