import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import '../data/services/notification_service.dart';
import '../data/services/database_service.dart';
import '../data/services/rag_service.dart';
import '../data/repositories/llm_repository_impl.dart';
import '../domain/repositories/ai_repository.dart';
import '../presentation/chat/chat_controller.dart';
import '../presentation/settings/settings_controller.dart';
import '../presentation/leads/leads_controller.dart';

class DependencyInjection {
  static Future<void> init() async {
    // 1. Environment
    await dotenv.load(fileName: ".env");
    
    // 2. Core settings controller (no dependencies)
    final settingsController = SettingsController();
    Get.put(settingsController, permanent: true);

    // 3. Persistent Services
    final notificationService = NotificationService();
    await notificationService.initialize();
    Get.put(notificationService, permanent: true);
    
    final databaseService = DatabaseService();
    await databaseService.initialize();
    Get.put(databaseService, permanent: true);

    final ragService = RAGService(databaseService);
    await ragService.initialize();
    Get.put(ragService, permanent: true);
    
    // 4. Repositories
    final aiRepository = LLMRepositoryImpl(databaseService, notificationService);
    Get.put<AIRepository>(aiRepository, permanent: true);
    
    // 5. App Controllers
    Get.put(ChatController(Get.find(), Get.find(), Get.find()), permanent: true);
    Get.put(LeadsController(), permanent: true);
  }
}
