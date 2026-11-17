import 'dart:convert';

import 'package:lab6_crypto/lab6_crypto.dart';
import 'package:lab6_server/repositories/crypto_repository.dart';
import 'package:lab6_server/repositories/session_repository.dart';
import 'package:lab6_server/utils/json_response.dart';
import 'package:shelf/shelf.dart';

class SessionsController {
  SessionsController({required this._rsaService, required this._cryptoRepository, required this._sessionRepository});

  final RsaService _rsaService;
  final CryptoRepository _cryptoRepository;
  final SessionRepository _sessionRepository;

  Future<Response> createSession(Request request) async {
    final rsaId = int.tryParse(request.headers['x-rsa-id'] ?? '');
    final sessionId = request.headers['x-session-id'];

    if (rsaId == null || sessionId == null || sessionId.isEmpty || sessionId.length > 128) {
      return jsonResponse(400, {'error': 'Invalid RSA ID or session ID'});
    }

    final rsaKeys = _cryptoRepository.getById(rsaId);

    if (rsaKeys == null) {
      return jsonResponse(404, {'error': 'RSA key not found'});
    }

    if (_sessionRepository.getById(sessionId) != null) {
      return jsonResponse(409, {'error': 'Session already exists'});
    }

    try {
      final body = await readJsonBody(request);
      final encryptedKey = body['encryptedKey'];

      if (encryptedKey is! String || encryptedKey.isEmpty) {
        return jsonResponse(400, {'error': 'Missing encryptedKey'});
      }

      final decrypted = _rsaService.decrypt(rsaKeys.privateKey, encryptedKey);

      final data = jsonDecode(decrypted);

      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid key data');
      }

      final key = data['key'];
      final iv = data['iv'];

      if (key is! String || iv is! String || base64Decode(key).length != 32 || base64Decode(iv).length != 12) {
        return jsonResponse(400, {'error': 'Invalid AES key or IV'});
      }

      final saved = _sessionRepository.save(sessionId, AesKey(key: key, iv: iv));

      if (!saved) {
        return jsonResponse(409, {'error': 'Session already exists'});
      }

      return jsonResponse(201, {'sessionId': sessionId, 'status': 'established'});
    } catch (_) {
      return jsonResponse(400, {'error': 'Invalid encrypted session data'});
    }
  }
}
