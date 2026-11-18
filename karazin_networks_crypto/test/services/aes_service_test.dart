import 'dart:convert';

import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:test/test.dart';

void main() {
  final service = AesService();
  late AesKey aesKey;

  setUpAll(() async {
    aesKey = await service.generateSecretKey();
  });

  test('Generates AES-256 key and IV', () {
    expect(base64Decode(aesKey.key).length, 32);
    expect(base64Decode(aesKey.iv).length, 12);
  });

  test('Encrypts and decrypts message', () async {
    const message = 'Hello, Server!';

    final encrypted = await service.encrypt(aesKey, message);
    final decrypted = await service.decrypt(aesKey, encrypted);

    expect(encrypted, isNot(message));
    expect(decrypted, message);
  });

  test('Supports Unicode messages', () async {
    const message = 'Привіт, сервер! 🔐';

    final encrypted = await service.encrypt(aesKey, message);
    final decrypted = await service.decrypt(aesKey, encrypted);

    expect(decrypted, message);
  });

  test('Uses a new nonce for every encryption', () async {
    final first = await service.encrypt(aesKey, 'Hello!');
    final second = await service.encrypt(aesKey, 'Hello!');

    expect(first, isNot(second));
  });

  test('Rejects modified ciphertext', () async {
    final encrypted = await service.encrypt(aesKey, 'Secret');
    final bytes = base64Decode(encrypted);

    bytes[12] ^= 1;

    expect(
      () => service.decrypt(aesKey, base64Encode(bytes)),
      throwsA(isA<Exception>()),
    );
  });
}
