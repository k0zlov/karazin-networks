import 'dart:convert';

import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:karazin_networks_server/controllers/messages_controller.dart';
import 'package:karazin_networks_server/repositories/session_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  final aes = AesService();
  final hashService = HashService();
  late DateTime now;
  late SessionRepository repository;
  late MessagesController controller;
  late AesKey key;

  setUp(() async {
    now = DateTime.utc(2026, 11, 18, 12);
    repository = SessionRepository(now: () => now);
    controller = MessagesController(
      aesService: aes,
      hashService: hashService,
      sessionRepository: repository,
    );
    key = await aes.generateSecretKey();
    expect(repository.save('original', key), isTrue);
  });

  Future<Response> send(String id, String cipherText, String message) async =>
      controller.sendMessage(
        Request(
          'POST',
          Uri.parse('http://localhost/api/messages'),
          headers: {'x-session-id': id, 'content-type': 'application/json'},
          body: jsonEncode({
            'cipherText': cipherText,
            'hash': await hashService.sha256(message),
          }),
        ),
      );

  test('Stores the ID, AES key and one-minute expiration in UTC', () {
    final session = repository.getById('original')!;
    expect(session.id, 'original');
    expect(session.aesKey, same(key));
    expect(session.expiresAt.isUtc, isTrue);
    expect(session.expiresAt, now.add(const Duration(minutes: 1)));
    expect(sessionLifetime, const Duration(minutes: 1));
    expect(repository.getById('missing'), isNull);
    expect(repository.save('', key), isFalse);
  });

  test('Supports a configured TTL and normalizes the clock to UTC', () {
    final local = now.toLocal();
    final custom = SessionRepository(
      lifetime: const Duration(seconds: 5),
      now: () => local,
    );
    custom.save('custom', key);
    expect(custom.getById('custom')!.expiresAt.isUtc, isTrue);
    expect(
      custom.getById('custom')!.expiresAt,
      now.add(const Duration(seconds: 5)),
    );
  });

  test('Uses DateTime.timestamp by default', () {
    final before = DateTime.timestamp();
    final realTime = SessionRepository()..save('real', key);
    final after = DateTime.timestamp();
    final expiresAt = realTime.getById('real')!.expiresAt;
    expect(expiresAt.isUtc, isTrue);
    expect(expiresAt.isBefore(before.add(sessionLifetime)), isFalse);
    expect(expiresAt.isAfter(after.add(sessionLifetime)), isFalse);
  });

  test('Accepts messages before and exactly at expiration', () async {
    final cipherText = await aes.encrypt(key, 'Привіт 🔐');
    final expiresAt = repository.getById('original')!.expiresAt;
    for (final time in [
      expiresAt.subtract(const Duration(microseconds: 1)),
      expiresAt,
    ]) {
      now = time;
      final response = await send('original', cipherText, 'Привіт 🔐');
      expect(response.statusCode, 200);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(
        await aes.decrypt(key, body['cipherText'] as String),
        startsWith('Привіт 🔐 | Received at '),
      );
    }
  });

  test(
    'Returns 440 before parsing a body and retains the expired session',
    () async {
      final original = repository.getById('original')!;
      now = original.expiresAt.add(const Duration(microseconds: 1));
      final response = await controller.sendMessage(
        Request(
          'POST',
          Uri.parse('http://localhost/api/messages'),
          headers: {'x-session-id': 'original'},
          body: 'invalid JSON and ciphertext',
        ),
      );
      expect(response.statusCode, 440);
      expect(jsonDecode(await response.readAsString()), {
        'error': 'Session expired',
      });
      expect(repository.isExpired(original), isTrue);
      expect(repository.getById('original'), same(original));
      expect(
        repository.save('original', await aes.generateSecretKey()),
        isFalse,
      );
      expect(repository.getById('original'), same(original));
    },
  );

  test(
    'Accepts a new key and ID while the old session continues to return 440',
    () async {
      now = now.add(const Duration(minutes: 2));
      final newKey = await aes.generateSecretKey();
      expect(repository.save('renewed', newKey), isTrue);
      final cipherText = await aes.encrypt(newKey, 'Same original message');
      expect((await send('original', cipherText, 'Привіт 🔐')).statusCode, 440);
      final response = await send(
        'renewed',
        cipherText,
        'Same original message',
      );
      expect(response.statusCode, 200);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(
        await aes.decrypt(newKey, body['cipherText'] as String),
        startsWith('Same original message | Received at '),
      );
      expect(repository.getById('original'), isNotNull);
    },
  );
}
