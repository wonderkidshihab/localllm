import 'package:langchain/langchain.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';
import 'package:get/get.dart';
import '../../presentation/settings/settings_controller.dart';
import 'package:langchain_openai/langchain_openai.dart';

class WebsiteScraperTool {
  static Tool create() {
    return Tool.fromFunction<String, String>(
      name: 'scrape_website',
      description: 'Fetches and extracts readable text from a URL to analyze a business. Input should be a valid URL string.',
      func: (final String inputStr, {final ToolOptions? options}) async {
        String url = inputStr;
        try {
          final map = jsonDecode(inputStr);
          if (map['url'] != null) url = map['url'];
        } catch (_) {}
        if (url.isEmpty || !url.startsWith('http')) {
           return "Invalid URL. Please provide a full http/https link.";
        }
        return _scrape(url);
      },
      inputJsonSchema: const {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'The full HTTP URL of the website to scrape.'
          }
        },
        'required': ['url']
      },
    );
  }

  static Future<String> _scrape(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return "Failed to fetch website. HTTP Status: ${response.statusCode}";
      }

      var document = html_parser.parse(response.body);
      
      // Remove scripts and styles
      document.querySelectorAll('script, style, noscript, iframe, svg').forEach((node) => node.remove());
      
      String text = document.body?.text ?? "";
      
      // Clean up whitespace
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      if (text.length > 8000) {
        text = "${text.substring(0, 8000)}... [Truncated]";
      }
      
      final llm = ChatOpenAI(
        apiKey: 'not-needed',
        baseUrl: Get.find<SettingsController>().lmStudioUrl.value,
        defaultOptions: const ChatOpenAIOptions(
          model: 'local-model',
          temperature: 0.1,
        ),
      );

      final messages = [
        SystemChatMessage(content: "You are a precise marketing analyst. You have been given the raw text of a website homepage. Analyze it and extract the marketing gaps (e.g., missing contact forms, empty content, missing testimonials) AND a brief description of what the business does. Keep your answer highly condensed and under 4 sentences. Do not converse with the user."),
        HumanChatMessage(content: ChatMessageContent.text(text))
      ];
      
      final res = await llm.invoke(PromptValue.chat(messages));
      return "Sub-Agent Gap Analysis for $url:\n${res.output.content}";
    } catch (e) {
      return "Error scraping or analyzing $url: $e";
    }
  }
}
