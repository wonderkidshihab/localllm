import 'package:get/get.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/ai_repository.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/services/database_service.dart';
import '../../data/services/rag_service.dart';
import 'package:uuid/uuid.dart';

class ChatController extends GetxController {
  final AIRepository _aiRepository;
  final DatabaseService _databaseService;
  final RAGService _ragService;
  
  final messages = <AppMessage>[].obs;
  final isThinking = false.obs;
  
  final activeThreadId = "".obs;
  final chatThreads = <Map<String, dynamic>>[].obs;

  ChatController(this._aiRepository, this._databaseService, this._ragService);

  @override
  void onInit() {
    super.onInit();
    _aiRepository.initializeAgent();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
     final threads = await _databaseService.getChatThreads();
     chatThreads.value = threads;
     
     if (threads.isNotEmpty) {
        switchThread(threads.first['id']);
     } else {
        createNewThread();
     }
  }

  void createNewThread() {
    activeThreadId.value = const Uuid().v4();
    messages.clear();
    // Do not save to DB immediately; save when first message happens.
  }

  Future<void> switchThread(String threadId) async {
     activeThreadId.value = threadId;
     final history = await _databaseService.getChatsForThread(threadId);
     messages.value = history.map((row) {
        return AppMessage(
          text: row['text'],
          role: row['role'] == 'user' ? MessageRole.user : MessageRole.ai,
        );
     }).toList();
  }

  void sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    // Auto-create thread on first active message
    if (messages.isEmpty) {
       final title = text.length > 25 ? "${text.substring(0, 25)}..." : text;
       await _databaseService.createChatThread(activeThreadId.value, title);
       chatThreads.value = await _databaseService.getChatThreads();
    }
    
    // Add & Save user message
    messages.add(AppMessage(text: text, role: MessageRole.user));
    _databaseService.saveChat(activeThreadId.value, 'user', text);
    
    isThinking.value = true;
    
    _ragService.queryContext(text).then((contextData) {
      final stream = _aiRepository.streamChat(text, contextData: contextData);
      
      AppMessage? aiMessage;
      
      stream.listen((messageUpdate) {
        if (aiMessage == null) {
          aiMessage = messageUpdate;
          messages.add(aiMessage!);
        } else {
          final index = messages.indexOf(aiMessage);
          if (index != -1) {
            aiMessage = messageUpdate;
            messages[index] = aiMessage!;
          }
        }
      }, onDone: () {
        isThinking.value = false;
        if (aiMessage != null && aiMessage!.status != MessageStatus.error) {
           _databaseService.saveChat(activeThreadId.value, 'ai', aiMessage!.text);
        }
      }, onError: (err) {
        isThinking.value = false;
        messages.add(AppMessage(text: "Error: $err", role: MessageRole.ai, status: MessageStatus.error));
      });
    });
  }

  Future<void> ingestDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      Get.snackbar('Ingesting', 'Reading PDF, generating embeddings locally...', duration: const Duration(seconds: 4));
      try {
        await _ragService.ingestPdf(result.files.single.path!);
        Get.snackbar('Success', 'PDF Embedded and synced to MemoryStore.');
      } catch (e) {
        Get.snackbar('Error', 'Ensure Embeddings model is loaded in LM Studio on port 1234: $e');
      }
    }
  }
}
