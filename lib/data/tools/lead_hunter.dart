import 'package:langchain/langchain.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../../presentation/settings/settings_controller.dart';
import 'dart:convert';

class LeadHunterTool {
  static Tool create() {
    return Tool.fromFunction<String, String>(
      name: 'search_leads',
      description: 'Search the web for local business leads. Input MUST be a JSON object. Required field: "query" (the business type to search for, e.g. "plumber" or "HVAC repair"). Optional fields: "location" (city/state to target, e.g. "Dallas, TX") and "limit" (integer, max results to return, default 7). Example input: {"query": "roofing company", "location": "Austin, TX", "limit": 5}',
      func: (final String inputStr, {final ToolOptions? options}) async {
        String query = "";
        String location = "";
        int limit = 7;

        try {
          final map = jsonDecode(inputStr);
          query = map['query'] ?? "";
          location = map['location'] ?? "";
          limit = map['limit'] ?? 7;
        } catch (_) {
          query = inputStr;
        }

        if (query.isEmpty) return "Error: Missing search query.";
        return _executeHunt(query, location: location, limit: limit);
      },
      inputJsonSchema: const {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'The business type or industry to search for. Examples: "plumber", "HVAC repair", "auto body shop". Do NOT include the location here, use the location field instead.'
          },
          'location': {
            'type': 'string',
            'description': 'The city and state to focus the search on. Examples: "Miami, FL", "Chicago, IL", "Dallas, TX". If omitted, the app will use the default location from settings.'
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of results to return. Must be between 1 and 10. Default is 7 if not specified.'
          }
        },
        'required': ['query']
      },
    );
  }

  /// Main dispatcher: reads hunt mode from settings and routes accordingly.
  static Future<String> _executeHunt(String query, {String location = "", int limit = 7}) async {
    final settings = Get.find<SettingsController>();
    final huntMode = settings.huntMode.value;

    if (huntMode == 'buried') {
      return _huntBuriedLeads(query, location: location, limit: limit);
    } else {
      return _huntCompetitors(query, location: location, limit: limit);
    }
  }

  // ─── MODE 1: BURIED LEADS ─────────────────────────────────────────────
  // Combines Page 2+ organic results with directory cross-referencing.
  static Future<String> _huntBuriedLeads(String query, {String location = "", int limit = 7}) async {
    final settings = Get.find<SettingsController>();
    final apiKey = settings.serperApiKey.value;
    if (apiKey.isEmpty) return "Search Error: Serper API key not configured.";

    String searchLocation = location.isNotEmpty ? location : settings.defaultSearchLocation.value;
    String localizedQuery = "$query in $searchLocation";

    // Strategy A: Page 2-3 offset (businesses that can't crack page 1)
    final offsetResults = await _serperRequest(apiKey, localizedQuery, num: limit, start: 10);

    // Strategy B: Directory cross-reference (businesses relying on third-party listings)
    String directoryQuery = "$query $searchLocation site:yelp.com OR site:yellowpages.com OR site:bbb.org";
    final directoryResults = await _serperRequest(apiKey, directoryQuery, num: limit);

    // Merge and deduplicate
    final merged = _mergeResults(offsetResults, directoryResults);

    if (merged.isEmpty) return "No buried leads found for '$query' in $searchLocation.";

    StringBuffer buffer = StringBuffer();
    buffer.writeln("### Buried Leads Discovery (businesses struggling with SEO):");
    buffer.writeln("*Strategy: Page 2+ results + Directory-only listings*\n");
    
    for (var item in merged.take(limit)) {
      buffer.writeln("- **${item['title']}**");
      buffer.writeln("  - Site: ${item['link']}");
      buffer.writeln("  - Info: ${item['snippet']}\n");
    }

    return buffer.toString();
  }

  // ─── MODE 2: TOP COMPETITORS ──────────────────────────────────────────
  // Standard page 1 results for competitive analysis.
  static Future<String> _huntCompetitors(String query, {String location = "", int limit = 7}) async {
    final settings = Get.find<SettingsController>();
    final apiKey = settings.serperApiKey.value;
    if (apiKey.isEmpty) return "Search Error: Serper API key not configured.";

    String searchLocation = location.isNotEmpty ? location : settings.defaultSearchLocation.value;
    String localizedQuery = "$query in $searchLocation";

    final results = await _serperRequest(apiKey, localizedQuery, num: limit);

    if (results.isEmpty) return "No competitors found for '$query' in $searchLocation.";

    StringBuffer buffer = StringBuffer();
    buffer.writeln("### Top Competitor Analysis (Page 1 Leaders):");
    buffer.writeln("*These businesses are already SEO-optimized.*\n");
    
    for (var item in results.take(limit)) {
      buffer.writeln("- **${item['title']}**");
      buffer.writeln("  - Site: ${item['link']}");
      buffer.writeln("  - Info: ${item['snippet']}\n");
    }

    return buffer.toString();
  }

  // ─── SERPER API CALL ──────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _serperRequest(
    String apiKey, String query, {int num = 7, int start = 0}
  ) async {
    try {
      final body = <String, dynamic>{
        'q': query,
        'num': num,
      };
      if (start > 0) body['start'] = start;

      final response = await http.post(
        Uri.parse('https://google.serper.dev/search'),
        headers: {
          'X-API-KEY': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List organic = data['organic'] ?? [];
        return organic.map<Map<String, dynamic>>((item) => {
          'title': item['title'] ?? 'Untitled',
          'link': item['link'] ?? '',
          'snippet': item['snippet'] ?? 'No description.',
          'domain': _extractDomain(item['link'] ?? ''),
        }).toList();
      }
    } catch (e) {
      // Silently fail individual requests; other strategy may succeed
    }
    return [];
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────

  /// Merges two result lists and deduplicates by domain.
  static List<Map<String, dynamic>> _mergeResults(
    List<Map<String, dynamic>> listA,
    List<Map<String, dynamic>> listB,
  ) {
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    for (final item in [...listA, ...listB]) {
      final domain = item['domain'] as String;
      if (domain.isNotEmpty && !seen.contains(domain)) {
        seen.add(domain);
        merged.add(item);
      }
    }

    return merged;
  }

  /// Extracts root domain from a URL for deduplication.
  static String _extractDomain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}
