import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:karazin_networks_server/models/session.dart';

const sessionLifetime = Duration(minutes: 1);

class SessionRepository {
  SessionRepository({this.lifetime = sessionLifetime, DateTime Function()? now})
    : _now = now ?? DateTime.timestamp;

  final Duration lifetime;
  final DateTime Function() _now;
  final Map<String, Session> _sessions = {};

  bool save(String sessionId, AesKey key) {
    if (sessionId.isEmpty || _sessions.containsKey(sessionId)) {
      return false;
    }

    _sessions[sessionId] = Session(
      id: sessionId,
      aesKey: key,
      expiresAt: _now().toUtc().add(lifetime),
    );
    return true;
  }

  Session? getById(String sessionId) => _sessions[sessionId];

  List<Session> getAll() => _sessions.values.toList();

  bool isExpired(Session session) => session.expiresAt.isBefore(_now());
}
