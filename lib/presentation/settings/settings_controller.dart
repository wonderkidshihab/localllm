import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends GetxController {
  final lmStudioUrl = 'http://localhost:1234/v1'.obs;
  final embeddingsModel = 'text-embedding-nomic-embed-text-v1.5'.obs;
  final serperApiKey = ''.obs;

  late SharedPreferences _prefs;
  final _isLoaded = false.obs;

  bool get isLoaded => _isLoaded.value;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    
    lmStudioUrl.value = _prefs.getString('lmStudioUrl') ?? 'http://localhost:1234/v1';
    embeddingsModel.value = _prefs.getString('embeddingsModel') ?? 'text-embedding-nomic-embed-text-v1.5';
    serperApiKey.value = _prefs.getString('serperApiKey') ?? const String.fromEnvironment('TAVILY_API_KEY', defaultValue: '');
    
    _isLoaded.value = true;
  }

  Future<void> saveSettings({String? url, String? model, String? apiKey}) async {
    if (url != null && url.isNotEmpty) {
       lmStudioUrl.value = url;
       await _prefs.setString('lmStudioUrl', url);
    }
    if (model != null && model.isNotEmpty) {
       embeddingsModel.value = model;
       await _prefs.setString('embeddingsModel', model);
    }
    if (apiKey != null && apiKey.isNotEmpty) {
       serperApiKey.value = apiKey;
       await _prefs.setString('serperApiKey', apiKey);
    }
  }
}
