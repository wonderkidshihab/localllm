import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/theme.dart';
import 'core/dependency_injection.dart';
import 'presentation/shared/widgets/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Centralized Initialization
  await DependencyInjection.init();

  runApp(
    GetMaterialApp(
      title: "Local AI Agency Command Center",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const MainShell()),
      ],
    ),
  );
}
