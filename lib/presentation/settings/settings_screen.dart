import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'settings_controller.dart';
import '../../data/services/database_service.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsController controller = Get.find<SettingsController>();

  SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Platform Configuration', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
          child: Obx(() {
            if (!controller.isLoaded) return const Center(child: CircularProgressIndicator());
            
            final urlCtrl = TextEditingController(text: controller.lmStudioUrl.value);
            final modelCtrl = TextEditingController(text: controller.embeddingsModel.value);
            final apiCtrl = TextEditingController(text: controller.serperApiKey.value);

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionHeader(theme, "Local Engine Settings"),
                const SizedBox(height: 16),
                _buildTextField(urlCtrl, 'LM Studio Base URL', 'http://localhost:1234/v1', LucideIcons.server),
                const SizedBox(height: 16),
                _buildTextField(modelCtrl, 'Embeddings Model ID', 'text-embedding-nomic...', LucideIcons.binary),
                const SizedBox(height: 16),
                _buildTextField(apiCtrl, 'Serper API Key', 'Required for Web Search', LucideIcons.key, obscure: true),
                const SizedBox(height: 24),
                ElevatedButton(
                   onPressed: () {
                      controller.saveSettings(url: urlCtrl.text, model: modelCtrl.text, apiKey: apiCtrl.text);
                      Get.snackbar('Success', 'Configuration saved to local shared preferences.');
                   },
                   child: const Text('Sync Configurations')
                ),
                const SizedBox(height: 48),
                _buildSectionHeader(theme, "Maintenance & Security", isWarning: true),
                const SizedBox(height: 16),
                _buildActionCard(
                  theme: theme,
                  icon: LucideIcons.trash2,
                  label: "Clear System Event Logs",
                  onPressed: () async {
                    await Get.find<DatabaseService>().clearLogs();
                    Get.snackbar('Console Cleared', 'All system events have been purged.');
                  }
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  theme: theme,
                  icon: LucideIcons.alertTriangle,
                  label: "Wipe Local Agency Database",
                  isCritical: true,
                  onPressed: () async {
                    Get.defaultDialog(
                      title: "Confirm Wipe",
                      middleText: "This erases all leads, chat threads, knowledge bases, and vectors permanently.",
                      textConfirm: "WIPE ALL DATA",
                      textCancel: "Cancel",
                      confirmTextColor: Colors.white,
                      onConfirm: () async {
                        await Get.find<DatabaseService>().clearDatabase();
                        Get.back();
                        Get.snackbar('Database Erased', 'All agency data has been removed.');
                      }
                    );
                  }
                )
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, {bool isWarning = false}) {
    return Text(
      title.toUpperCase(), 
      style: GoogleFonts.inter(
        fontSize: 12, 
        fontWeight: FontWeight.bold, 
        letterSpacing: 1.2,
        color: isWarning ? Colors.redAccent : theme.colorScheme.primary
      )
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
       controller: ctrl,
       obscureText: obscure,
       decoration: InputDecoration(
         labelText: label,
         hintText: hint,
         prefixIcon: Icon(icon, size: 20),
       ),
    );
  }

  Widget _buildActionCard({
    required ThemeData theme, 
    required IconData icon, 
    required String label, 
    required VoidCallback onPressed,
    bool isCritical = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isCritical ? Colors.red.withValues(alpha: 0.05) : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isCritical ? Colors.redAccent.withValues(alpha: 0.2) : theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isCritical ? Colors.redAccent : theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: isCritical ? Colors.redAccent : null)),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
