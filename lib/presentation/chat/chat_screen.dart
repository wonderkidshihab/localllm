import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'chat_controller.dart';
import '../../domain/entities/message.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatController controller = Get.find<ChatController>();
  final TextEditingController textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('AI Agency Pipeline', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: false,
        leading: isDesktop ? null : IconButton(
           icon: const Icon(LucideIcons.menu),
           onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.filePlus, size: 20),
            onPressed: controller.ingestDocument,
            tooltip: 'Add Context (PDF)',
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: () => controller.createNewThread(),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text("New Thread"),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          )
        ],
      ),
      drawer: isDesktop ? null : _buildMobileDrawer(context),
      body: Column(
        children: [
          Expanded(
            child: Obx(
              () => ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? (MediaQuery.of(context).size.width * 0.1) : 16, 
                  vertical: 24
                ),
                itemCount: controller.messages.length + (controller.isThinking.value ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == controller.messages.length && controller.isThinking.value) {
                    return _buildThinkingIndicator();
                  }
                  final msg = controller.messages[index];
                  return _buildMessageBubble(msg, theme);
                },
              ),
            ),
          ),
          _buildInputArea(theme, isDesktop),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(AppMessage msg, ThemeData theme) {
    final isUser = msg.role == MessageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.7 : 0.85)),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary : theme.cardTheme.color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
          boxShadow: isUser ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: MarkdownBody(
          data: msg.text,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: theme.textTheme.bodyLarge?.copyWith(
              color: isUser ? Colors.white : theme.textTheme.bodyLarge?.color,
              height: 1.5,
              fontSize: 15,
            ),
            code: GoogleFonts.firaCode(
              backgroundColor: isUser ? Colors.black26 : theme.dividerColor.withValues(alpha: 0.1),
              color: isUser ? Colors.white : theme.colorScheme.primary,
            ),
            codeblockDecoration: BoxDecoration(
              color: isUser ? Colors.black26 : theme.dividerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? (MediaQuery.of(context).size.width * 0.15) : 16,
        12,
        isDesktop ? (MediaQuery.of(context).size.width * 0.15) : 16,
        24
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05))),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: textController,
                maxLines: 5,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Type your agency command...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    controller.sendMessage(val);
                    textController.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  controller.sendMessage(textController.text);
                  textController.clear();
                }
              },
              icon: Icon(LucideIcons.arrowUp, color: theme.colorScheme.primary),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    // Port of the desktop sidebar for mobile drawer
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
            onTap: () => Get.back(),
          ),
          ListTile(
            leading: const Icon(LucideIcons.users),
            title: const Text("Leads"),
            onTap: () { Get.back(); Get.toNamed('/leads'); },
          ),
          ListTile(
            leading: const Icon(LucideIcons.terminal),
            title: const Text("Logs"),
            onTap: () { Get.back(); Get.toNamed('/logs'); },
          ),
          ListTile(
            leading: const Icon(LucideIcons.settings),
            title: const Text("Settings"),
            onTap: () { Get.back(); Get.toNamed('/settings'); },
          ),
        ],
      ),
    );
  }
}
