import 'package:material_ui/material_ui.dart';

class SessionStatus extends StatelessWidget {
  const SessionStatus({
    required this.isConnecting,
    required this.isConnected,
    required this.error,
    required this.onRetry,
    super.key,
  });

  final bool isConnecting;
  final bool isConnected;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isConnected) const Text('Session established'),
        if (isConnecting) ...[
          const Text('Establishing session…'),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (error.isNotEmpty) ...[
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Reconnect')),
        ],
      ],
    );
  }
}
