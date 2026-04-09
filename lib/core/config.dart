class AppConfig {
  static const String llmBaseUrl = 'http://localhost:1234/v1'; // 10.0.2.2:1234 for Android emulator
  static const String llmModel = 'local-model';
  
  static const String notificationChannelId = 'high_priority_alerts';
  static const String notificationChannelName = 'High Priority Alerts';
  static const String notificationChannelDesc = 'Used for agent task completion or lead finding alerts';
}
