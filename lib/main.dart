import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'core/theme.dart';
import 'data/services/notification_service.dart';
import 'data/services/database_service.dart';
import 'data/services/rag_service.dart';
import 'data/repositories/llm_repository_impl.dart';
import 'domain/repositories/ai_repository.dart';
import 'presentation/chat/chat_controller.dart';
import 'presentation/settings/settings_controller.dart';
import 'presentation/shared/widgets/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Init Services
  final settingsController = SettingsController();
  Get.put(settingsController);

  final notificationService = NotificationService();
  await notificationService.initialize();
  Get.put(notificationService);
  
  final databaseService = DatabaseService();
  await databaseService.initialize();
  Get.put(databaseService);

  final ragService = RAGService(databaseService);
  await ragService.initialize();
  Get.put(ragService);
  
  // Init Repositories
  final aiRepository = LLMRepositoryImpl(databaseService, notificationService);
  Get.put<AIRepository>(aiRepository);
  
  // Init Controllers
  Get.put(ChatController(Get.find(), Get.find(), Get.find()));

  runApp(
    GetMaterialApp(
      title: "Local AI Agency Command Center",
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const MainShell()),
      ],
    ),
  );
}
