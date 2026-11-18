import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';

class SessionRepository {
  final Map<String, AesKey> _sessions = {};

  bool save(String sessionId, AesKey key) {
    if (sessionId.isEmpty || _sessions.containsKey(sessionId)) {
      return false;
    }

    _sessions[sessionId] = key;
    return true;
  }

  AesKey? getById(String sessionId) => _sessions[sessionId];
}
