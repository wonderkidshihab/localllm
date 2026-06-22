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
      description: 'Scrape a business website and return an automated marketing gap analysis. Input MUST be a JSON object with a "url" field containing the full website URL (must start with http:// or https://). Example input: {"url": "https://example-plumber.com"}. Returns a condensed analysis of the business and their marketing weaknesses.',
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
            'description': 'The complete website URL to scrape and analyze. Must start with http:// or https://. Example: "https://example-plumber.com"'
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
        SystemChatMessage(content: 
          "ROLE: You are a precise digital marketing analyst working for a local SEO agency.\n\n"
          "TASK: You have been given the raw extracted text from a business website homepage. Analyze it and produce a structured gap analysis.\n\n"
          "YOUR OUTPUT MUST INCLUDE EXACTLY THESE TWO SECTIONS:\n"
          "1. BUSINESS SUMMARY: What does this business do? What services do they offer? (2 sentences max)\n"
          "2. MARKETING GAPS: List every weakness you can identify. Look for:\n"
          "   - Missing or broken contact information (no phone, no email, no contact form)\n"
          "   - Thin or outdated content (copyright year, sparse pages)\n"
          "   - No customer testimonials or reviews\n"
          "   - No social media presence or broken social links\n"
          "   - Poor mobile responsiveness indicators\n"
          "   - Missing calls-to-action\n"
          "   - No blog or content marketing\n"
          "   - Generic stock imagery vs. real business photos\n"
          "   - Missing SSL/HTTPS\n\n"
          "RULES:\n"
          "- Keep your entire response under 8 sentences.\n"
          "- Be specific and factual. Do not guess or assume.\n"
          "- Do NOT greet the user or add conversational text. Output the analysis directly."
        ),
        HumanChatMessage(content: ChatMessageContent.text(text))
      ];
      
      final res = await llm.invoke(PromptValue.chat(messages));
      return "Sub-Agent Gap Analysis for $url:\n${res.output.content}";
    } catch (e) {
      return "Error scraping or analyzing $url: $e";
    }
  }
}
