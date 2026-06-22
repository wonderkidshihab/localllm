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
      description: 'Send a desktop push notification to the agency owner. Use this ONLY when you have completed a task and want to notify the user of a result (e.g., "Found 3 new leads" or "Lead saved successfully"). Input must be a JSON object with a "message" field containing the notification text.',
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
            'description': 'The notification message to display to the user. Keep it short and informative, under 50 words.'
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

      final huntMode = Get.find<SettingsController>().huntMode.value;
      final String huntContext = huntMode == 'buried'
          ? "CURRENT HUNT MODE: BURIED LEADS.\n"
            "The search tool is pre-configured to return businesses that are INVISIBLE online — they appear on Google page 2-3, or only exist on directory sites like Yelp/YellowPages/BBB.\n"
            "These businesses are your IDEAL prospects because they clearly need digital marketing help.\n"
            "When you analyze these leads, focus exclusively on their WEAKNESSES: poor Google rankings, missing or outdated websites, no social media presence, reliance on third-party directories, missing contact forms, no Google Business Profile optimization.\n"
            "Your outreach email must directly reference their specific gaps and offer concrete solutions."
          : "CURRENT HUNT MODE: TOP COMPETITORS.\n"
            "The search tool returns page 1 Google leaders — businesses that are already well-optimized.\n"
            "These results are for competitive intelligence and benchmarking. Note that these businesses are harder to convert as clients because they already invest in SEO.\n"
            "When analyzing, focus on what makes them successful so the agency owner can learn from their strategies.";

      List<ChatMessage> messages = [
        SystemChatMessage(content: 
          "ROLE: You are a Senior Agency Growth Agent embedded in a local-first CRM application. You help a digital marketing agency owner discover, analyze, and qualify potential business leads.\n\n"
          "$huntContext\n\n"
          "YOUR AVAILABLE TOOLS:\n"
          "1. 'search_leads' — Searches the web for business leads. You MUST pass a JSON object: {\"query\": \"plumber\", \"location\": \"Miami, FL\", \"limit\": 5}. The 'query' field is required. The 'location' and 'limit' fields are optional.\n"
          "2. 'scrape_website' — Fetches a website and returns an automated gap analysis. You MUST pass a JSON object: {\"url\": \"https://example.com\"}. The URL must start with http:// or https://.\n"
          "3. 'save_local_lead' — Saves a qualified lead to the agency's local database. You MUST pass a JSON object with ALL of these fields: {\"businessName\": \"...\", \"contactInfo\": \"...\", \"marketingGaps\": \"...\", \"source\": \"...\", \"outreachDraft\": \"...\"}. The outreachDraft must be a complete, ready-to-send cold email.\n"
          "4. 'send_alert' — Sends a push notification to the user. Use ONLY after completing work. Pass: {\"message\": \"...\"}\n\n"
          "MANDATORY WORKFLOW (follow these steps IN ORDER, do NOT skip or repeat any step):\n"
          "Step 1: Call 'search_leads' EXACTLY ONCE with the user's query. Wait for results.\n"
          "Step 2: From the search results, pick 1 or 2 promising leads. Call 'scrape_website' on their URLs. Do NOT scrape more than 2 websites.\n"
          "Step 3: Read the gap analysis returned by the scraper. Based on the specific gaps found, write a personalized cold outreach email (3-5 paragraphs) that directly addresses their pain points.\n"
          "Step 4: Call 'save_local_lead' to store each lead with all required fields filled in.\n"
          "Step 5: STOP. Provide a brief summary to the user of what you found and saved. Do NOT call search_leads again. Do NOT start another cycle.\n\n"
          "STRICT RULES:\n"
          "- NEVER call 'search_leads' more than once in a single conversation.\n"
          "- NEVER scrape more than 2 websites per session.\n"
          "- NEVER loop back to searching after saving a lead.\n"
          "- If the user asks a general question (not about finding leads), answer it directly WITHOUT using any tools.\n"
          "- All tool inputs MUST be valid JSON objects. Never pass plain strings to tools.\n"
          "- If a tool returns an error, report it to the user and stop. Do not retry."
        ),
      ];
      
      if (contextData != null && contextData.isNotEmpty) {
        messages.add(SystemChatMessage(content: "LOCAL KNOWLEDGE BASE CONTEXT:\nThe following information was retrieved from the agency's local document store. Use it to enrich your analysis if relevant. Do not mention that you received this context to the user.\n\n$contextData"));
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
