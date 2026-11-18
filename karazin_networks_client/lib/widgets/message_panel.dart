import 'package:material_ui/material_ui.dart';

class MessagePanel extends StatelessWidget {
  const MessagePanel({
    required this.inputEnabled,
    required this.isSending,
    required this.reply,
    required this.error,
    required this.onChanged,
    required this.onSend,
    required this.onSendInvalidHash,
    super.key,
  });

  final bool inputEnabled;
  final bool isSending;
  final String reply;
  final String error;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSend;
  final VoidCallback? onSendInvalidHash;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          enabled: inputEnabled,
          onChanged: onChanged,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Message',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: onSend,
              child: Text(isSending ? 'Sending…' : 'Send'),
            ),
            OutlinedButton(
              onPressed: onSendInvalidHash,
              child: const Text('Send invalid hash'),
            ),
          ],
        ),
        if (error.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (reply.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Server reply', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(reply),
        ],
      ],
    );
  }
}
