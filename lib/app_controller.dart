import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/offline_analyzer.dart';
import 'data/app_database.dart';
import 'models/ai_analysis.dart';
import 'models/memory_item.dart';
import 'models/notification.dart';
import 'services/ai_service.dart';
import 'services/notification_service.dart';
import 'services/reminder_service.dart';

class CapturedApp {
  const CapturedApp({required this.packageName, required this.name});

  final String packageName;
  final String name;
}

class AppController extends ChangeNotifier {
  AppController({
    required this.database,
    required this.aiService,
    required this.notificationService,
    required this.preferences,
    ReminderService? reminderService,
  }) : reminderService = reminderService ?? ReminderService();

  final AppDatabase database;
  final AIService aiService;
  final NotificationService notificationService;
  final SharedPreferences preferences;
  final ReminderService reminderService;

  static const _blockedAppsKey = 'blockedNotificationApps';
  static const _mutedCategoriesKey = 'mutedNotificationCategories';
  static const _muteLowPriorityKey = 'muteLowPriorityNotifications';
  static const _remindersEnabledKey = 'deadlineRemindersEnabled';
  static const _categoryOverridesKey = 'categoryOverrides';

  List<MemoryItem> items = const [];
  List<NotificationRecord> logs = const [];
  List<MemoryItem> searchResults = const [];
  AIStatus aiStatus = const AIStatus(
    initialized: false,
    classifier: false,
    embedding: false,
    languageModel: false,
    message: 'Preparing local AI',
  );
  bool notificationAccessGranted = false;
  bool loading = true;
  String searchQuery = '';
  StreamSubscription<NotificationEvent>? _eventSubscription;
  final Set<String> _inFlight = <String>{};
  bool _pendingDrained = false;

  bool get isOnboarded => preferences.getBool('isOnboarded') ?? false;
  bool get remindersEnabled =>
      preferences.getBool(_remindersEnabledKey) ?? false;
  bool get muteLowPriority => preferences.getBool(_muteLowPriorityKey) ?? false;
  Set<String> get blockedPackages =>
      preferences.getStringList(_blockedAppsKey)?.toSet() ?? const {};
  Set<NotificationCategory> get mutedCategories =>
      (preferences.getStringList(_mutedCategoriesKey) ?? const [])
          .map(NotificationCategoryX.fromString)
          .toSet();
  List<CapturedApp> get capturedApps {
    final apps = <String, CapturedApp>{};
    for (final record in logs) {
      apps[record.payload.packageName] = CapturedApp(
        packageName: record.payload.packageName,
        name: record.payload.appName,
      );
    }
    for (final packageName in blockedPackages) {
      apps.putIfAbsent(
        packageName,
        () => CapturedApp(packageName: packageName, name: packageName),
      );
    }
    return apps.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> initialize() async {
    await refresh();
    notificationAccessGranted = await notificationService.isAccessGranted();
    aiStatus = await aiService.status();
    _eventSubscription = notificationService.events.listen(_handleEvent);

    if (aiStatus.languageModel) await _processPendingNotifications();
    loading = false;
    notifyListeners();
  }

  Future<void> refreshAiStatus() async {
    final wasReady = aiStatus.languageModel;
    aiStatus = await aiService.status();
    notifyListeners();
    if (!wasReady && aiStatus.languageModel) {
      await _processPendingNotifications();
    }
  }

  Future<String?> downloadLanguageModel() async {
    final error = await aiService.downloadLanguageModel();
    await refreshAiStatus();
    return error;
  }

  Future<void> _processPendingNotifications() async {
    if (_pendingDrained || !aiStatus.languageModel) return;
    _pendingDrained = true;
    final pending = await notificationService.popPendingNotifications();
    for (final payload in pending) {
      await _process(payload);
    }
  }

  Future<void> refresh() async {
    items = await database.getItems();
    final now = DateTime.now();
    final dueSnoozes = items.where((item) {
      final scheduled = scheduledAt(item);
      return item.status == 'snoozed' &&
          scheduled != null &&
          !scheduled.isAfter(now);
    });
    for (final item in dueSnoozes) {
      await database.updateItemStatus(item.id, 'active');
    }
    if (dueSnoozes.isNotEmpty) {
      items = await database.getItems();
    }
    logs = await database.getLogs();
    if (searchQuery.isNotEmpty) {
      searchResults = await database.searchItems(searchQuery);
    }
    notifyListeners();
  }

  Future<void> _handleEvent(NotificationEvent event) async {
    await _process(event.payload, event.analysis);
  }

  Future<void> _process(NotificationPayload payload,
      [AIAnalysis? knownAnalysis]) async {
    if (!aiStatus.languageModel) return;
    if (!_inFlight.add(payload.id)) return;
    try {
      if (blockedPackages.contains(payload.packageName)) {
        await notificationService.markProcessed(payload);
        return;
      }
      final fingerprint = notificationFingerprint(payload);
      final isDuplicate = await database.hasRecentNotification(
        fingerprint,
        since: DateTime.now()
            .subtract(const Duration(hours: 24))
            .millisecondsSinceEpoch,
      );
      if (isDuplicate) {
        await notificationService.markProcessed(payload);
        return;
      }
      var analysis =
          knownAnalysis ?? await aiService.analyzeNotification(payload);
      analysis = _applyCategoryOverride(payload, analysis);
      if (_isMuted(analysis)) {
        await notificationService.markProcessed(payload);
        return;
      }
      if (_shouldUseLanguageModel(analysis)) {
        final summary = await aiService.summarizeNotification(payload);
        if (summary != null && summary.trim().isNotEmpty) {
          analysis = analysis.copyWith(
            summary: summary.trim(),
            modelVersion: '${analysis.modelVersion}+qwen3-0.6b-int4',
            accelerator: '${analysis.accelerator ?? 'CPU'} + LiteRT-LM',
          );
        }
      }
      final proposedMemory = OfflineAnalyzer.toMemoryItem(payload, analysis)
          ?.withContentFingerprint(fingerprint);
      final existingMemory = proposedMemory == null
          ? null
          : await database.findOpenItemByFingerprint(fingerprint);
      final memory = existingMemory ?? proposedMemory;
      final record = NotificationRecord(
        id: payload.id,
        payload: payload,
        processed: true,
        actionTaken: memory == null
            ? 'IGNORE'
            : existingMemory == null
                ? 'CREATE'
                : 'UPDATE',
        category: analysis.category,
        categoryConfidence: analysis.confidence,
        importance: analysis.importance,
        embedding: analysis.embedding,
        aiProcessed: analysis.aiProcessed,
        aiModelVersion: analysis.modelVersion,
        summary: analysis.summary,
        aiProcessingError: analysis.error,
        memoryItemId: memory?.id,
        contentFingerprint: fingerprint,
      );
      await database.upsertNotification(record);
      if (existingMemory != null) {
        await database.touchItem(existingMemory.id, analysis.importance);
      } else if (memory != null) {
        await database.upsertItem(memory);
        await _scheduleDueReminder(memory);
      }
      await notificationService.markProcessed(payload);
      await refresh();
    } finally {
      _inFlight.remove(payload.id);
    }
  }

  bool _shouldUseLanguageModel(AIAnalysis analysis) {
    return const {
      NotificationCategory.banking,
      NotificationCategory.finance,
      NotificationCategory.delivery,
      NotificationCategory.travel,
    }.contains(analysis.category);
  }

  bool _isMuted(AIAnalysis analysis) =>
      mutedCategories.contains(analysis.category) ||
      (muteLowPriority && analysis.importance < 70);

  AIAnalysis _applyCategoryOverride(
    NotificationPayload payload,
    AIAnalysis analysis,
  ) {
    final value = _categoryOverrides()[_overrideKey(payload)];
    if (value == null) return analysis;
    final category = NotificationCategoryX.fromString(value);
    return analysis.copyWith(category: category);
  }

  Map<String, String> _categoryOverrides() {
    final values = preferences.getStringList(_categoryOverridesKey) ?? const [];
    return Map.fromEntries(values.map((value) {
      final separator = value.lastIndexOf('|');
      return separator < 1
          ? null
          : MapEntry(
              value.substring(0, separator), value.substring(separator + 1));
    }).whereType<MapEntry<String, String>>());
  }

  String _overrideKey(NotificationPayload payload) =>
      '${payload.packageName}|${_normalized(payload.title)}';

  static String notificationFingerprint(NotificationPayload payload) => [
        payload.packageName,
        payload.senderName ?? '',
        payload.title,
        payload.text,
      ].map(_normalized).join('|');

  static String _normalized(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> completeOnboarding() async {
    await preferences.setBool('isOnboarded', true);
    notifyListeners();
  }

  Future<void> openNotificationSettings() async {
    await notificationService.openAccessSettings();
    notificationAccessGranted = await notificationService.isAccessGranted();
    notifyListeners();
  }

  Future<void> updateStatus(MemoryItem item, String status) async {
    await database.updateItemStatus(item.id, status);
    if (status == 'completed' || status == 'active') {
      await reminderService.cancel(item.id);
    }
    await refresh();
  }

  Future<void> deleteItem(MemoryItem item) async {
    await database.deleteItem(item.id);
    await reminderService.cancel(item.id);
    await refresh();
  }

  Future<void> rescheduleItem(
    MemoryItem item,
    DateTime dueAt, {
    bool snooze = false,
  }) async {
    await database.updateItemSchedule(
      item.id,
      status: 'snoozed',
      date: _dateValue(dueAt),
      time: _timeValue(dueAt),
    );
    if (remindersEnabled) {
      await reminderService.requestPermission();
      await reminderService.schedule(
        id: item.id,
        title: snooze ? 'Reminder: ${item.title}' : 'Due soon: ${item.title}',
        body: item.description,
        at: snooze ? dueAt : _reminderTime(dueAt),
      );
    }
    await refresh();
  }

  Future<void> updateCategory(
      MemoryItem item, NotificationCategory category) async {
    await database.updateItemCategory(item.id, category.label);
    final packageName = item.sourcePackage;
    if (packageName != null && packageName.isNotEmpty) {
      final values = _categoryOverrides();
      values['$packageName|${_normalized(item.title)}'] = category.name;
      await preferences.setStringList(
        _categoryOverridesKey,
        values.entries.map((entry) => '${entry.key}|${entry.value}').toList(),
      );
    }
    await refresh();
  }

  Future<void> setAppBlocked(String packageName, bool blocked) async {
    final values = blockedPackages;
    blocked ? values.add(packageName) : values.remove(packageName);
    await preferences.setStringList(_blockedAppsKey, values.toList());
    notifyListeners();
  }

  Future<void> setCategoryMuted(
      NotificationCategory category, bool muted) async {
    final values = mutedCategories;
    muted ? values.add(category) : values.remove(category);
    await preferences.setStringList(
        _mutedCategoriesKey, values.map((value) => value.name).toList());
    notifyListeners();
  }

  Future<void> setMuteLowPriority(bool value) async {
    await preferences.setBool(_muteLowPriorityKey, value);
    notifyListeners();
  }

  Future<void> setRemindersEnabled(bool value) async {
    await preferences.setBool(_remindersEnabledKey, value);
    if (value) await reminderService.requestPermission();
    notifyListeners();
  }

  Future<void> clearAllHistory() async {
    await database.clearAllData();
    await notificationService.clearQueue();
    await reminderService.cancelAll();
    await refresh();
  }

  Future<void> clearDataForApp(CapturedApp app) async {
    final relatedItems = items
        .where((item) =>
            item.sourcePackage == app.packageName ||
            (item.sourcePackage == null && item.sourceApp == app.name))
        .toList();
    await database.clearDataForApp(
        packageName: app.packageName, appName: app.name);
    for (final item in relatedItems) {
      await reminderService.cancel(item.id);
    }
    await refresh();
  }

  DateTime? scheduledAt(MemoryItem item) {
    if (item.date == null) return null;
    return DateTime.tryParse('${item.date}T${item.time ?? '09:00'}');
  }

  Future<void> _scheduleDueReminder(MemoryItem item) async {
    final dueAt = scheduledAt(item);
    if (!remindersEnabled || dueAt == null || !dueAt.isAfter(DateTime.now())) {
      return;
    }
    await reminderService.schedule(
      id: item.id,
      title: 'Due soon: ${item.title}',
      body: item.description,
      at: _reminderTime(dueAt),
    );
  }

  DateTime _reminderTime(DateTime dueAt) {
    final preferred = dueAt.subtract(const Duration(hours: 1));
    final earliest = DateTime.now().add(const Duration(minutes: 1));
    return preferred.isAfter(earliest) ? preferred : earliest;
  }

  String _dateValue(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _timeValue(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> search(String query) async {
    searchQuery = query;
    if (query.trim().isEmpty) {
      searchResults = const [];
    } else {
      searchResults = await database.searchItems(query);
      if (searchResults.isEmpty) {
        final vector = await aiService.embedNotification(query);
        final records = await database.semanticSearch(vector);
        searchResults = items
            .where((item) =>
                records.any((record) => record.memoryItemId == item.id))
            .toList();
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
