import 'package:langchain/langchain.dart';
import '../services/database_service.dart';
import 'dart:convert';

class LocalLeadSaver {
  static Tool create(DatabaseService db) {
    return Tool.fromFunction<String, String>(
      name: 'save_local_lead',
      description: 'Saves a business lead to the local database securely. Use this tool instead of external APIs. Provide the following string fields recursively inside a json map: businessName, contactInfo, marketingGaps, source.',
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
          'businessName': {'type': 'string', 'description': 'Name of the business'},
          'contactInfo': {'type': 'string', 'description': 'Phone, email, or website'},
          'marketingGaps': {'type': 'string', 'description': 'What they are missing (e.g. No website)'},
          'source': {'type': 'string', 'description': 'Where this lead was found'},
          'outreachDraft': {'type': 'string', 'description': 'A highly personalized cold email written to them targeting the exactly discovered marketing gaps.'}
        },
        'required': ['businessName', 'contactInfo', 'marketingGaps', 'source', 'outreachDraft']
      },
    );
  }
}
