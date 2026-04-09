import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../chat/chat_screen.dart';
import '../../leads/leads_dashboard.dart';
import '../../logs/logs_screen.dart';
import '../../settings/settings_screen.dart';

class DashboardController extends GetxController {
  var selectedIndex = 0.obs;
  
  void changeIndex(int index) {
    selectedIndex.value = index;
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardController());

    final List<Widget> pages = [
      const ChatScreen(),
      LeadsDashboard(),
      LogsScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          
          return Obx(() {
            final content = IndexedStack(
              index: controller.selectedIndex.value,
              children: pages,
            );

            if (isDesktop) {
              return Row(
                children: [
                  _buildSidebar(context, controller),
                  VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
                  Expanded(child: content),
                ],
              );
            } else {
              // Mobile implementation: Use IndexedStack with BottomNav or Drawer
              return Scaffold(
                drawer: _buildMobileDrawer(context, controller), // Need to move this from ChatScreen or implement here
                body: content,
              );
            }
          });
        },
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, DashboardController controller) {
    return Container(
      width: 260,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.bot, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  "CommandCenter",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() => ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _NavItem(
                  icon: LucideIcons.messageSquare,
                  label: "AI Agency Chat",
                  isActive: controller.selectedIndex.value == 0,
                  onTap: () => controller.changeIndex(0),
                ),
                _NavItem(
                  icon: LucideIcons.users,
                  label: "Leads Dashboard",
                  isActive: controller.selectedIndex.value == 1,
                  onTap: () => controller.changeIndex(1),
                ),
                _NavItem(
                  icon: LucideIcons.terminal,
                  label: "System Logs",
                  isActive: controller.selectedIndex.value == 2,
                  onTap: () => controller.changeIndex(2),
                ),
                _NavItem(
                  icon: LucideIcons.settings,
                  label: "Settings",
                  isActive: controller.selectedIndex.value == 3,
                  onTap: () => controller.changeIndex(3),
                ),
              ],
            )),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const _UserCard(),
                const SizedBox(height: 12),
                Text(
                  "Local Vision Agency Hub v1.0",
                  style: GoogleFonts.inter(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer(BuildContext context, DashboardController controller) {
    return Drawer(
      child: Column(
        children: [
          const UserAccountsDrawerHeader(
            accountName: Text("Agency Owner"),
            accountEmail: Text("Local-First AI Hub"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(LucideIcons.bot, color: Color(0xFF4F46E5)),
            ),
            decoration: BoxDecoration(color: Color(0xFF4F46E5)),
          ),
          ListTile(
            leading: const Icon(LucideIcons.messageSquare),
            title: const Text("Chat"),
            onTap: () { controller.changeIndex(0); Get.back(); },
          ),
          ListTile(
            leading: const Icon(LucideIcons.users),
            title: const Text("Leads"),
            onTap: () { controller.changeIndex(1); Get.back(); },
          ),
          ListTile(
            leading: const Icon(LucideIcons.terminal),
            title: const Text("Logs"),
            onTap: () { controller.changeIndex(2); Get.back(); },
          ),
          ListTile(
            leading: const Icon(LucideIcons.settings),
            title: const Text("Settings"),
            onTap: () { controller.changeIndex(3); Get.back(); },
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF4F46E5),
            child: Icon(Icons.person, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Agency Owner",
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Local-First Mode",
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
