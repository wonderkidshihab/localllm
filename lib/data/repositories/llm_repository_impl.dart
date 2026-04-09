import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/entities/message.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../tools/local_lead_saver.dart';
import '../tools/lead_hunter.dart';
import '../tools/website_scraper.dart';
import 'dart:convert';
import 'package:get/get.dart';
import '../../presentation/settings/settings_controller.dart';

class SystemNotifierTool {
  static Tool create(NotificationService service, DatabaseService db) {
    return Tool.fromFunction<String, String>(
      name: 'send_alert',
      description: 'Send a push notification alert to the user.',
      func: (final String inputStr, {final ToolOptions? options}) async {
        String message = inputStr;
        try {
          final map = jsonDecode(inputStr);
          if (map['message'] != null) message = map['message'];
        } catch (_) {}
        if (message.isEmpty) return "Missing message";
        await service.sendAlert('Agent Alert', message);
        await db.logEvent("Pushed alert: $message");
        return "Alert sent.";
      },
      inputJsonSchema: const {
        'type': 'object',
        'properties': {
          'message': {
            'type': 'string',
            'description': 'The alert message content'
          }
        },
        'required': ['message']
      },
    );
  }
}

class LLMRepositoryImpl implements AIRepository {
  final DatabaseService _databaseService;
  final NotificationService _notificationService;
  
  late final List<Tool> _tools;
  bool _isInit = false;
  
  LLMRepositoryImpl(this._databaseService, this._notificationService);

  @override
  Future<void> initializeAgent() async {
    _tools = [
      LeadHunterTool.create(),
      WebsiteScraperTool.create(),
      LocalLeadSaver.create(_databaseService),
      SystemNotifierTool.create(_notificationService, _databaseService),
    ];
    _isInit = true;
  }

  @override
  Stream<AppMessage> streamChat(String prompt, {String? contextData}) async* {
    if (!_isInit) {
      yield AppMessage(
        text: "Agent not initialized.",
        role: MessageRole.ai,
        status: MessageStatus.error,
      );
      return;
    }

    try {
      yield AppMessage(text: "Thinking...", role: MessageRole.ai, status: MessageStatus.thinking);

      String currentOutput = "";

      final llm = ChatOpenAI(
        apiKey: 'not-needed',
        baseUrl: Get.find<SettingsController>().lmStudioUrl.value,
        defaultOptions: const ChatOpenAIOptions(
          model: 'local-model',
          temperature: 0.7,
        ),
      );

      final modelWithTools = llm.bind(ChatOpenAIOptions(
        tools: _tools.map((t) => ToolSpec(
          name: t.name, 
          description: t.description,
          inputJsonSchema: t.inputJsonSchema,
        )).toList(),
      ));

      List<ChatMessage> messages = [
        SystemChatMessage(content: "You are a Senior Agency Growth Agent. Your goal is to deeply analyze leads without getting stuck in infinite loops.\nCRITICAL RULES:\n1. Use the search_leads tool EXACTLY ONCE. Do not search repeatedly.\n2. Pick only 1 or 2 sites from the results and use the scrape_website tool on them. The scrape tool will automatically return a gap analysis for you. Do not scrape more than 2 sites.\n3. Read the analysis. If they have gaps, write a highly personalized cold outreach email directly targeting those gaps.\n4. Use the save_local_lead tool to store the lead + your outreach draft.\n5. STOP ITERATING. Once a lead is saved, do not search again. End the loop and wait for the user to ask another question."),
      ];
      
      if (contextData != null && contextData.isNotEmpty) {
        messages.add(SystemChatMessage(content: "Use the following local knowledge base context perfectly to assist the user if relevant:\n\n$contextData"));
      }
      
      messages.add(HumanChatMessage(content: ChatMessageContent.text(prompt)));

      int maxIterations = 10;
      for (int i = 0; i < maxIterations; i++) {
        final res = await modelWithTools.invoke(PromptValue.chat(messages));
        messages.add(res.output);
        
        final aiMsg = res.output;

        if (aiMsg.toolCalls.isEmpty) {
          if (aiMsg.content.isNotEmpty) {
             currentOutput += "\n${aiMsg.content}";
          }
          yield AppMessage(text: currentOutput.trim(), role: MessageRole.ai, status: MessageStatus.complete);
          return;
        } else {
          for (final call in aiMsg.toolCalls) {
            currentOutput += "\n*Running tool: ${call.name}...*";
            yield AppMessage(text: currentOutput.trim(), role: MessageRole.ai, status: MessageStatus.thinking);
            
            final tool = _tools.firstWhere((t) => t.name == call.name);
            final dynamic toolInputStr = call.arguments;
            
            String toolInput = "{}";
            if (toolInputStr is String) {
               toolInput = toolInputStr;
            } else if (toolInputStr is Map) {
               toolInput = jsonEncode(toolInputStr);
            }

            await _databaseService.logEvent("Tool initialized: ${call.name}\nArgs: $toolInput");

            try {
              final tRes = await tool.invoke(toolInput);
              messages.add(ToolChatMessage(content: tRes.toString(), toolCallId: call.id));
              
              currentOutput += "\n*Tool result: $tRes*\n";
              await _databaseService.logEvent("Tool success: ${call.name}\nResponse: $tRes");
            } catch (toolErr) {
              await _databaseService.logEvent("Tool error: ${call.name}\nException: $toolErr");
              messages.add(ToolChatMessage(content: "Error executing tool: $toolErr", toolCallId: call.id));
              currentOutput += "\n*Tool error: $toolErr*\n";
            }
            yield AppMessage(text: currentOutput.trim(), role: MessageRole.ai, status: MessageStatus.thinking);
          }
        }
      }
      
      yield AppMessage(text: "Max iterations reached.\n$currentOutput", role: MessageRole.ai, status: MessageStatus.complete);
    } catch (e) {
      await _databaseService.logEvent("LLM Error: $e");
      yield AppMessage(text: "An error occurred: $e", role: MessageRole.ai, status: MessageStatus.error);
    }
  }
}
