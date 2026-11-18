import 'package:go_router/go_router.dart';
import 'package:karazin_networks_client/models/session_info.dart';
import 'package:karazin_networks_client/navigation/routes.dart';
import 'package:karazin_networks_client/repositories/crypto_repository.dart';
import 'package:material_ui/material_ui.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({required this.repository, super.key});

  final CryptoRepository repository;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<SessionInfo> _sessions = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final sessions = await widget.repository.getSessions();
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load sessions. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatExpiration(BuildContext context, DateTime expiresAt) {
    final local = expiresAt.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final hours = local.hour.toString().padLeft(2, '0');
    final minutes = local.minute.toString().padLeft(2, '0');
    final seconds = local.second.toString().padLeft(2, '0');
    return '$date, $hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              const MainRoute().go(context);
            }
          },
        ),
        title: const Text('Sessions'),
        actions: [
          IconButton(
            tooltip: 'Refresh sessions',
            onPressed: _isLoading ? null : _loadSessions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadSessions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_sessions.isEmpty) {
      return const Center(child: Text('No sessions yet.'));
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Expiration times are shown in your local time zone.'),
        const SizedBox(height: 12),
        for (final session in _sessions)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.isValid ? 'Valid' : 'Expired',
                    style: TextStyle(
                      color: session.isValid
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(session.sessionId),
                  const SizedBox(height: 8),
                  Text(
                    'Expires: ${_formatExpiration(context, session.expiresAt)}',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
