import 'package:langchain/langchain.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../../presentation/settings/settings_controller.dart';
import 'dart:convert';

class LeadHunterTool {
  static Tool create() {
    return Tool.fromFunction<String, String>(
      name: 'search_leads',
      description: 'Searches the web for local business leads. Input should be a search query.',
      func: (final String inputStr, {final ToolOptions? options}) async {
        String query = inputStr;
        try {
          final map = jsonDecode(inputStr);
          if (map['query'] != null) query = map['query'];
        } catch (_) {}
        if (query.isEmpty) return "Missing query.";
        return _search(query);
      },
      inputJsonSchema: const {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Search query to find leads'
          }
        },
        'required': ['query']
      },
    );
  }

  static Future<String> _search(String query) async {
    final apiKey = Get.find<SettingsController>().serperApiKey.value; 
    if (apiKey.isEmpty) {
       return "Simulated search result for: $query. To use real search, configure API key in Settings.";
    }
    
    try {
      final response = await http.post(
        Uri.parse('https://google.serper.dev/search'),
        headers: {
          'X-API-KEY': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'q': query,
        }),
      );

      if (response.statusCode == 200) {
        return response.body; // Return full JSON structure back to the agent
      } else {
        return "Search failed: ${response.statusCode}\n${response.body}";
      }
    } catch (e) {
      return "Search error: $e";
    }
  }
}
