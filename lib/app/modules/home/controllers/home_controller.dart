import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';

class HomeController extends GetxController {
  final TextEditingController inputController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  
  final rxMessages = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;

  late final ConversationBufferMemory memory;
  late final AgentExecutor agentExecutor;

  @override
  void onInit() {
    super.onInit();
    
    // 1. Setup Chat Model (Pointing to local LMStudio server)
    final chatModel = ChatOpenAI(
      apiKey: 'dummy', // Not required locally, but needed by parameter
      baseUrl: 'http://127.0.0.1:1234/v1',
      defaultOptions: const ChatOpenAIOptions(
        model: 'local-model',
        temperature: 0.7,
      ),
    );

    // 2. Define the exact Tool
    final getWeatherTool = Tool.fromFunction(
      name: 'get_weather',
      description: 'Get the current weather for a specific location.',
      inputJsonSchema: {
        'type': 'object',
        'properties': {
          'location': {
            'type': 'string',
            'description': 'The city or location to get weather for, e.g., Tokyo or London.'
          }
        },
        'required': ['location']
      },
      func: (Map<String, dynamic> input) {
        final location = input['location'] ?? 'Unknown location';
        return getWeather(location);
      },
      getInputFromJson: (Map<String, dynamic> json) => json, 
    );

    // 3. Setup Memory for conversational context
    memory = ConversationBufferMemory(returnMessages: true);

    // 4. Construct the Tool Calling Agent
    final agent = ToolsAgent.fromLLMAndTools(
      llm: chatModel,
      tools: [getWeatherTool],
      memory: memory,
    );

    // 5. Build the Executor to enforce loop sanity constraints
    agentExecutor = AgentExecutor(
      agent: agent,
      memory: memory,
      returnIntermediateSteps: true,
      maxIterations: 5, 
    );
  }

  @override
  void onClose() {
    inputController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  String getWeather(String location) {
    if (location.toLowerCase().contains("london")) {
      return 'The weather in London is mostly cloudy, 15 degrees Celsius.';
    } else if (location.toLowerCase().contains("tokyo")) {
      return 'The weather in Tokyo is sunny, 22 degrees Celsius.';
    }
    return 'The weather in $location is currently sunny, 20 degrees Celsius.';
  }

  void sendMessage() async {
    final text = inputController.text.trim();
    if (text.isEmpty) return;

    inputController.clear();
    
    rxMessages.add({
      'role': 'user',
      'content': text,
    });
    
    isLoading.value = true;
    _scrollToBottom();
    
    try {
      // The executor natively handles step execution logic!
      final res = await agentExecutor.invoke({'input': text});
      
      final steps = res['intermediate_steps'] as List<AgentStep>? ?? [];
      final output = res['output'] as String;
      
      // We playback the intermediate steps into the UI
      for (var step in steps) {
        final toolName = step.action.tool;
        final toolInput = step.action.toolInput;
        
        rxMessages.add({
           'role': 'assistant',
           'tool_calls': [
              {
                 'function': {
                    'name': toolName,
                    'arguments': toolInput.toString(),
                 }
              }
           ]
        });
        
        rxMessages.add({
          'role': 'tool',
          'name': toolName,
          'content': step.observation,
        });
      }
      
      // Finally emit the LLM's final response
      rxMessages.add({
        'role': 'assistant',
        'content': output,
      });

    } catch (e) {
      rxMessages.add({
        'role': 'assistant',
        'content': 'Error communicating with LM Studio via LangChain: $e'
      });
    }

    isLoading.value = false;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
