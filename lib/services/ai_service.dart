import 'package:flutter/services.dart';

import '../ai/offline_analyzer.dart';
import '../models/ai_analysis.dart';
import '../models/notification.dart';

class AIStatus {
  const AIStatus({
    required this.initialized,
    required this.classifier,
    required this.embedding,
    required this.languageModel,
    required this.message,
    this.languageModelMessage,
    this.languageModelDownloading = false,
    this.languageModelDownloadProgress = 0,
    this.languageModelDownloadBytes = 0,
    this.languageModelDownloadTotalBytes = 0,
    this.languageModelStorageBytes = 0,
    this.languageModelStorageAvailableBytes = 0,
  });

  final bool initialized;
  final bool classifier;
  final bool embedding;
  final bool languageModel;
  final String message;
  final String? languageModelMessage;
  final bool languageModelDownloading;
  final int languageModelDownloadProgress;
  final int languageModelDownloadBytes;
  final int languageModelDownloadTotalBytes;
  final int languageModelStorageBytes;
  final int languageModelStorageAvailableBytes;

  factory AIStatus.fromMap(Map<Object?, Object?> map) => AIStatus(
        initialized: map['initialized'] == true,
        classifier: map['classifier'] == true,
        embedding: map['embedding'] == true,
        languageModel: map['languageModel'] == true,
        message: map['message']?.toString() ?? 'Offline fallback ready',
        languageModelMessage: map['languageModelMessage']?.toString(),
        languageModelDownloading: map['languageModelDownloading'] == true,
        languageModelDownloadProgress:
            (map['languageModelDownloadProgress'] as num?)?.toInt() ?? 0,
        languageModelDownloadBytes:
            (map['languageModelDownloadBytes'] as num?)?.toInt() ?? 0,
        languageModelDownloadTotalBytes:
            (map['languageModelDownloadTotalBytes'] as num?)?.toInt() ?? 0,
        languageModelStorageBytes:
            (map['languageModelStorageBytes'] as num?)?.toInt() ?? 0,
        languageModelStorageAvailableBytes:
            (map['languageModelStorageAvailableBytes'] as num?)?.toInt() ?? 0,
      );
}

class AIService {
  static const _channel = MethodChannel('com.thingstoremember/ai');

  Future<AIAnalysis> analyzeNotification(
      NotificationPayload notification) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'analyzeNotification',
        notification.toMap(),
      );
      if (result != null) return AIAnalysis.fromMap(result);
    } on PlatformException {
      // The Dart implementation is deliberately a complete offline fallback.
    }
    return OfflineAnalyzer.analyze(notification);
  }

  Future<NotificationCategory> classifyNotification(
      NotificationPayload notification) async {
    final analysis = await analyzeNotification(notification);
    return analysis.category;
  }

  Future<List<double>> embedNotification(String text) async {
    try {
      final result = await _channel
          .invokeMethod<List<Object?>>('embedNotification', {'text': text});
      if (result != null && result.isNotEmpty) {
        return result.map((value) => (value as num).toDouble()).toList();
      }
    } on PlatformException {
      // Use the same deterministic, local fallback as notification processing.
    }
    return OfflineAnalyzer.embed(text);
  }

  Future<String?> summarizeNotification(
      NotificationPayload notification) async {
    try {
      return await _channel.invokeMethod<String>(
          'summarizeNotification', notification.toMap());
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<String?> downloadLanguageModel() async {
    try {
      await _channel.invokeMethod<bool>('downloadLanguageModel');
      return null;
    } on PlatformException catch (error) {
      return error.message ??
          'The local language model could not be downloaded.';
    } on MissingPluginException {
      return 'This Android build does not include the LiteRT-LM installer.';
    }
  }

  Future<AIStatus> status() async {
    try {
      final result =
          await _channel.invokeMethod<Map<Object?, Object?>>('aiStatus');
      return result == null
          ? const AIStatus(
              initialized: false,
              classifier: false,
              embedding: false,
              languageModel: false,
              message: 'Offline fallback ready')
          : AIStatus.fromMap(result);
    } on PlatformException {
      return const AIStatus(
          initialized: false,
          classifier: false,
          embedding: false,
          languageModel: false,
          message: 'Flutter offline fallback ready');
    } on MissingPluginException {
      return const AIStatus(
          initialized: false,
          classifier: false,
          embedding: false,
          languageModel: false,
          message: 'Flutter offline fallback ready');
    }
  }
}
