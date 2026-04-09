import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'leads_controller.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../shared/widgets/confirm_dialog.dart';

class LeadsDashboard extends StatelessWidget {
  final LeadsController controller = Get.put(LeadsController());

  LeadsDashboard({super.key});

  Future<void> exportLeads(List<Map<String, dynamic>> leads) async {
    List<List<dynamic>> rows = [];
    rows.add(["Business Name", "Contact Info", "Marketing Gaps", "Source", "Outreach Draft", "Date"]);
    for (var lead in leads) {
      rows.add([
        lead['businessName'],
        lead['contactInfo'],
        lead['marketingGaps'],
        lead['source'],
        lead['outreachDraft'],
        lead['timestamp']
      ]);
    }
    
    StringBuffer csvBuffer = StringBuffer();
    for (var r in rows) {
      final line = r.map((item) => '"${item?.toString().replaceAll('"', '""') ?? ''}"').join(',');
      csvBuffer.writeln(line);
    }
    String csvData = csvBuffer.toString();
    
    final dir = await getApplicationDocumentsDirectory();
    final path = "${dir.path}/leads_export_${DateTime.now().millisecondsSinceEpoch}.csv";
    final file = File(path);
    await file.writeAsString(csvData);
    Get.snackbar("Exported", "Saved to: $path", duration: const Duration(seconds: 5));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Obx(() => Text(
          controller.isSelectionMode.value ? "${controller.selectedIds.length} Selected" : "Prospect Pipeline", 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold)
        )),
        actions: [
          Obx(() {
            if (controller.isSelectionMode.value) {
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
                    onPressed: () {
                      ConfirmDialog.show(
                        context,
                        title: "Bulk Deletion",
                        message: "This will permanently erase ${controller.selectedIds.length} leads. This action is irreversible once the undo period expires.",
                        confirmLabel: "PURGE DATA",
                        onConfirm: () => controller.deleteSelected(),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: controller.toggleSelectionMode,
                  ),
                ],
              );
            }
            return Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.download),
                  tooltip: "Export to CSV",
                  color: theme.colorScheme.primary,
                  onPressed: () async {
                     if (controller.leads.isNotEmpty) {
                       await exportLeads(controller.leads);
                     } else {
                       Get.snackbar("Error", "No leads to export.");
                     }
                  },
                ),
                const SizedBox(width: 8),
              ],
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
           return const Center(child: CircularProgressIndicator());
        }
        
        final leads = controller.leads;
        if (leads.isEmpty) {
           return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(LucideIcons.ghost, size: 64, color: Colors.grey),
                 const SizedBox(height: 16),
                 Text("Zero leads discovered. Start a chat hunting session!", style: GoogleFonts.inter(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5))),
               ],
             )
           );
        }
        
        if (isDesktop) {
          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 500,
              mainAxisExtent: 380, // Increased slightly for checkbox
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
            ),
            itemCount: leads.length,
            itemBuilder: (context, index) => _LeadCard(lead: leads[index], key: ValueKey(leads[index]['id'])),
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leads.length,
            itemBuilder: (context, index) => _LeadCard(lead: leads[index], key: ValueKey(leads[index]['id'])),
          );
        }
      })
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;

  const _LeadCard({required this.lead, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final LeadsController controller = Get.find<LeadsController>();
    final id = lead['id'] as int;

    return Obx(() {
      final isSelected = controller.selectedIds.contains(id);
      final isInSelectionMode = controller.isSelectionMode.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onLongPress: () {
            if (!isInSelectionMode) {
              controller.toggleSelectionMode();
              controller.toggleLeadSelection(id);
            }
          },
          onTap: () {
            if (isInSelectionMode) {
              controller.toggleLeadSelection(id);
            }
          },
          child: Stack(
            children: [
              Dismissible(
                key: ValueKey("dismiss_$id"),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(LucideIcons.trash, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await ConfirmDialog.show(
                    context,
                    title: "Delete Lead",
                    message: "Are you sure you want to move this prospect to the waste bin?",
                    confirmLabel: "YES, DELETE",
                    onConfirm: () {}, // Handled by Dismissible
                  ) ?? false;
                },
                onDismissed: (direction) {
                  controller.requestSingleDeletion(Map.from(lead));
                },
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected && isInSelectionMode 
                          ? theme.colorScheme.primary 
                          : theme.dividerColor.withValues(alpha: 0.05),
                      width: isSelected ? 2 : 1
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: Icon(LucideIcons.building, color: theme.colorScheme.primary, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                    lead['businessName'] ?? 'Unknown', 
                                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)
                                  ),
                                  Text(
                                    lead['contactInfo'] ?? 'No Contact Info', 
                                    style: theme.textTheme.bodyMedium,
                                    maxLines: 1,
                                  ),
                                ],
                              )
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text("Marketing Discovery", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SelectableText(
                            lead['marketingGaps'] ?? 'None identified',
                            style: GoogleFonts.inter(fontSize: 14, height: 1.5)
                          ),
                        ),
                        if (lead['outreachDraft'] != null && lead['outreachDraft'].isNotEmpty) ...[
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => _showOutreachDialog(context, theme, lead),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.mail, size: 12, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Text("OUTREACH READY", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                                  const SizedBox(width: 4),
                                  const Icon(LucideIcons.externalLink, size: 10, color: Colors.green),
                                ],
                              ),
                            ),
                          )
                        ],
                      ],
                    ),
                  )
                ),
              ),
              if (isInSelectionMode)
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : Colors.white70,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? LucideIcons.check : LucideIcons.circle, 
                      size: 20, 
                      color: isSelected ? Colors.white : Colors.grey
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  void _showOutreachDialog(BuildContext context, ThemeData theme, Map<String, dynamic> lead) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.mail, color: theme.colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Drafting Outreach", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        Text(lead['businessName'] ?? 'Lead', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                constraints: const BoxConstraints(maxHeight: 400),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    lead['outreachDraft'] ?? '',
                    style: GoogleFonts.inter(fontSize: 14, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: lead['outreachDraft'] ?? ''));
                        Get.snackbar(
                          "Copied!", 
                          "Outreach draft copied to clipboard.",
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: theme.colorScheme.primary,
                          colorText: Colors.white,
                        );
                      },
                      icon: const Icon(LucideIcons.copy, size: 18),
                      label: const Text("Copy Draft"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
