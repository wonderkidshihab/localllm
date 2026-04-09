enum MessageRole { user, ai, system }
enum MessageStatus { thinking, complete, error }

class AppMessage {
  final String text;
  final MessageRole role;
  final MessageStatus status;

  AppMessage({
    required this.text,
    required this.role,
    this.status = MessageStatus.complete,
  });

  AppMessage copyWith({
    String? text,
    MessageRole? role,
    MessageStatus? status,
  }) {
    return AppMessage(
      text: text ?? this.text,
      role: role ?? this.role,
      status: status ?? this.status,
    );
  }
}
