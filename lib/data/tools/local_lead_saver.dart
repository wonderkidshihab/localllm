import 'package:langchain/langchain.dart';
import '../services/database_service.dart';
import 'dart:convert';

class LocalLeadSaver {
  static Tool create(DatabaseService db) {
    return Tool.fromFunction<String, String>(
      name: 'save_local_lead',
      description: 'Save a qualified business lead to the agency local database. Input MUST be a JSON object with ALL of these required fields: "businessName" (the company name), "contactInfo" (phone number, email, or website URL), "marketingGaps" (a summary of their digital marketing weaknesses), "source" (where this lead was discovered, e.g. "Google Search"), and "outreachDraft" (a complete cold outreach email ready to send). Example: {"businessName": "ABC Plumbing", "contactInfo": "(305) 555-1234", "marketingGaps": "No website, only Yelp listing", "source": "Google Search Page 2", "outreachDraft": "Dear ABC Plumbing team..."}',
      func: (final String inputStr, {final ToolOptions? options}) async {
        try {
          final map = jsonDecode(inputStr);
          final businessName = map['businessName']?.toString() ?? 'Unknown';
          final contactInfo = map['contactInfo']?.toString() ?? 'Unknown';
          final marketingGaps = map['marketingGaps']?.toString() ?? 'None identified';
          final source = map['source']?.toString() ?? 'Agent Search';
          final outreachDraft = map['outreachDraft']?.toString() ?? 'No draft written';

          if (businessName == 'Unknown' && contactInfo == 'Unknown') {
            return "Failed to save: provide real businessName and contactInfo.";
          }

          await db.saveLead(businessName, contactInfo, marketingGaps, source, outreachDraft);
          
          return "Successfully saved lead locally to database. Tell the user it's securely stored in their leads tab.";
        } catch (e) {
          return "Error saving lead: $e";
        }
      },
      inputJsonSchema: const {
        'type': 'object',
        'properties': {
          'businessName': {'type': 'string', 'description': 'The full business name exactly as it appears on their website or listing. Example: "Miami Pro Plumbing LLC"'},
          'contactInfo': {'type': 'string', 'description': 'The business contact details: phone number, email address, or website URL. Include as much as available. Example: "(305) 555-1234 | info@example.com | https://example.com"'},
          'marketingGaps': {'type': 'string', 'description': 'A detailed summary of the digital marketing weaknesses identified during analysis. Be specific. Example: "No SSL certificate, copyright 2019, no Google reviews, missing contact form, no blog"'},
          'source': {'type': 'string', 'description': 'Where this lead was discovered. Example: "Google Search Page 2" or "Yelp Directory Listing"'},
          'outreachDraft': {'type': 'string', 'description': 'A complete, ready-to-send cold outreach email (3-5 paragraphs) personalized to this specific business. Must reference their specific marketing gaps and offer concrete solutions. Do NOT write a generic template.'}
        },
        'required': ['businessName', 'contactInfo', 'marketingGaps', 'source', 'outreachDraft']
      },
    );
  }
}
