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
            final locationCtrl = TextEditingController(text: controller.defaultSearchLocation.value);

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
                const SizedBox(height: 16),
                _buildTextField(locationCtrl, 'Home Base Location', 'e.g., Miami, FL', LucideIcons.mapPin),
                const SizedBox(height: 24),
                ElevatedButton(
                   onPressed: () {
                      controller.saveSettings(
                        url: urlCtrl.text, 
                        model: modelCtrl.text, 
                        apiKey: apiCtrl.text,
                        location: locationCtrl.text,
                      );
                      Get.snackbar('Success', 'Configuration saved to local shared preferences.');
                   },
                   child: const Text('Sync Configurations')
                ),
                const SizedBox(height: 48),
                _buildSectionHeader(theme, "Lead Hunting Strategy"),
                const SizedBox(height: 12),
                Text(
                  "Choose how the AI searches for prospects. 'Buried Leads' finds businesses struggling with SEO—your ideal clients.",
                  style: GoogleFonts.inter(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), height: 1.5),
                ),
                const SizedBox(height: 16),
                Obx(() => Row(
                  children: [
                    Expanded(
                      child: _HuntModeCard(
                        theme: theme,
                        icon: LucideIcons.eyeOff,
                        label: "Buried Leads",
                        description: "Page 2+ & directory-only businesses",
                        isActive: controller.huntMode.value == 'buried',
                        onTap: () => controller.setHuntMode('buried'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HuntModeCard(
                        theme: theme,
                        icon: LucideIcons.trophy,
                        label: "Top Competitors",
                        description: "Page 1 results for competitive analysis",
                        isActive: controller.huntMode.value == 'competitors',
                        onTap: () => controller.setHuntMode('competitors'),
                      ),
                    ),
                  ],
                )),
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

class _HuntModeCard extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String label;
  final String description;
  final bool isActive;
  final VoidCallback onTap;

  const _HuntModeCard({
    required this.theme,
    required this.icon,
    required this.label,
    required this.description,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.1),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.dividerColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: isActive ? theme.colorScheme.primary : Colors.grey),
                ),
                const Spacer(),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text("ACTIVE", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.inter(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}
