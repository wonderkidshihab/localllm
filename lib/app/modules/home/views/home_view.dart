import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LMStudio Tool Calling Test'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              return ListView.builder(
                controller: controller.scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: controller.rxMessages.length,
                itemBuilder: (context, index) {
                  final msg = controller.rxMessages[index];
                  return _buildMessageBubble(msg);
                },
              );
            }),
          ),
          Obx(() => controller.isLoading.value 
            ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ) 
            : const SizedBox.shrink()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final role = msg['role'];
    final content = msg['content'];
    final toolCalls = msg['tool_calls'];

    bool isUser = role == 'user';
    bool isTool = role == 'tool';
    
    String displayText = content ?? '';
    
    if (toolCalls != null) {
      displayText = 'Tool Call(s):\n';
      for (var tc in toolCalls) {
         displayText += '${tc['function']['name']}(${tc['function']['arguments']})\n';
      }
    }
    
    if (isTool) {
      displayText = 'Tool Result (${msg['name']}):\n$content';
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : (isTool ? Colors.orange[100] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(displayText),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.inputController,
              decoration: const InputDecoration(
                hintText: 'Ask about the weather (e.g. "What is the weather in Tokyo?")',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => controller.sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: controller.sendMessage,
          ),
        ],
      ),
    );
  }
}
