import '../entities/message.dart';

abstract class AIRepository {
  Stream<AppMessage> streamChat(String prompt, {String? contextData});
  Future<void> initializeAgent();
}
