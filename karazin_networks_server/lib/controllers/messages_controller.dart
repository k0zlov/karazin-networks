import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:karazin_networks_server/repositories/session_repository.dart';
import 'package:karazin_networks_server/utils/json_response.dart';
import 'package:shelf/shelf.dart';

class MessagesController {
  MessagesController({
    required this._aesService,
    required this._hashService,
    required this._sessionRepository,
  });

  final AesService _aesService;
  final HashService _hashService;
  final SessionRepository _sessionRepository;

  Future<Response> sendMessage(Request request) async {
    final sessionId = request.headers['x-session-id'];

    if (sessionId == null || sessionId.isEmpty) {
      return jsonResponse(400, {'error': 'Missing session ID'});
    }

    final session = _sessionRepository.getById(sessionId);

    if (session == null) {
      return jsonResponse(404, {'error': 'Session not found'});
    }

    if (_sessionRepository.isExpired(session)) {
      return jsonResponse(440, {'error': 'Session expired'});
    }

    final aesKey = session.aesKey;

    try {
      final body = await readJsonBody(request);
      final cipherText = body['cipherText'];

      if (cipherText is! String || cipherText.isEmpty) {
        return jsonResponse(400, {'error': 'Missing cipherText'});
      }

      final hash = body['hash'];

      if (hash is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
        return jsonResponse(400, {'error': 'Invalid message hash'});
      }

      final message = await _aesService.decrypt(aesKey, cipherText);
      final expectedHash = await _hashService.sha256(message);

      if (hash != expectedHash) {
        return jsonResponse(422, {'error': 'Message hash mismatch'});
      }

      final receivedAt = DateTime.timestamp().toIso8601String();

      final responseMessage = '$message | Received at $receivedAt';

      final encryptedResponse = await _aesService.encrypt(
        aesKey,
        responseMessage,
      );

      return jsonResponse(200, {
        'sessionId': sessionId,
        'cipherText': encryptedResponse,
      });
    } catch (_) {
      return jsonResponse(400, {'error': 'Invalid encrypted message'});
    }
  }
}
