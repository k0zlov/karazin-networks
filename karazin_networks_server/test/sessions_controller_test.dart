import 'dart:convert';

import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:karazin_networks_server/controllers/sessions_controller.dart';
import 'package:karazin_networks_server/repositories/crypto_repository.dart';
import 'package:karazin_networks_server/repositories/session_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late SessionRepository repository;
  late SessionsController controller;
  final key = AesKey(key: 'sensitive-key', iv: 'sensitive-iv');

  setUp(() {
    now = DateTime.utc(2026, 11, 18, 12);
    repository = SessionRepository(now: () => now);
    controller = SessionsController(
      rsaService: RsaService(),
      cryptoRepository: CryptoRepository(),
      sessionRepository: repository,
    );
  });

  Future<List<dynamic>> listSessions() async {
    final response = controller.getSessions(
      Request('GET', Uri.parse('http://localhost/api/sessions')),
    );
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], startsWith('application/json'));
    return jsonDecode(await response.readAsString()) as List<dynamic>;
  }

  test('Returns an empty array when no sessions exist', () async {
    expect(await listSessions(), isEmpty);
  });

  test(
    'Lists valid and expired sessions in creation order without secrets',
    () async {
      repository.save('expired', key);
      now = now.add(const Duration(seconds: 30));
      repository.save('valid', key);
      now = now.add(const Duration(seconds: 31));

      expect(await listSessions(), [
        {
          'sessionId': 'expired',
          'isValid': false,
          'expiresAt': DateTime.utc(2026, 11, 18, 12, 1).toIso8601String(),
        },
        {
          'sessionId': 'valid',
          'isValid': true,
          'expiresAt': DateTime.utc(2026, 11, 18, 12, 1, 30).toIso8601String(),
        },
      ]);
      expect(repository.getById('expired'), isNotNull);
      final copy = repository.getAll();
      copy.clear();
      expect(repository.getAll(), hasLength(2));
    },
  );

  test('Recalculates validity on every request and retains sessions after expiration', () async {
    repository.save('boundary', key);
    now = now.add(sessionLifetime);
    expect((await listSessions()).single['isValid'], isTrue);
    now = now.add(const Duration(microseconds: 1));
    final sessions = await listSessions();
    expect(sessions.single['isValid'], isFalse);
    expect(sessions.single['sessionId'], 'boundary');
    expect(repository.getById('boundary'), isNotNull);
  });
}
