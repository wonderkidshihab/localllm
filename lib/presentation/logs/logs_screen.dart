import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/database_service.dart';
import 'package:intl/intl.dart';

class LogsScreen extends StatelessWidget {
  final db = Get.find<DatabaseService>();

  LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("System Events", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: db.getLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
             return Center(child: Text("Console is empty.", style: GoogleFonts.firaCode(color: theme.textTheme.bodySmall?.color)));
          }
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: logs.length,
              separatorBuilder: (context, index) => Divider(height: 1, indent: 16, endIndent: 16, color: theme.dividerColor.withValues(alpha: 0.05)),
              itemBuilder: (context, index) {
                final log = logs[index];
                final dateObj = DateTime.tryParse(log['timestamp'] ?? '');
                final date = dateObj != null ? DateFormat('HH:mm:ss').format(dateObj.toLocal()) : '--:--:--';
                
                final eventText = log['event'] ?? 'Unknown Event';
                final isError = eventText.toLowerCase().contains('error') || eventText.toLowerCase().contains('fail');
                final isSuccess = eventText.toLowerCase().contains('success') || eventText.toLowerCase().contains('saved') || eventText.toLowerCase().contains('indexed');
                
                Color statusColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
                if (isError) statusColor = Colors.redAccent;
                if (isSuccess) statusColor = const Color(0xFF10B981); // Professional emerald green

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          date, 
                          style: GoogleFonts.firaCode(color: theme.textTheme.bodySmall?.color, fontSize: 11)
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SelectableText(
                          eventText, 
                          style: GoogleFonts.firaCode(
                            color: statusColor, 
                            fontSize: 12, 
                            height: 1.5,
                            fontWeight: isError ? FontWeight.bold : FontWeight.normal,
                          )
                        )
                      )
                    ],
                  ),
                );
              }
            ),
          );
        }
      )
    );
  }
}
