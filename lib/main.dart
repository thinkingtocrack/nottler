import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_controller.dart';
import 'data/app_database.dart';
import 'services/ai_service.dart';
import 'services/notification_service.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final preferences = await SharedPreferences.getInstance();
  final controller = AppController(
    database: database,
    aiService: AIService(),
    notificationService: NotificationService(),
    preferences: preferences,
  );
  await controller.initialize();
  runApp(NottlerApp(controller: controller));
}
