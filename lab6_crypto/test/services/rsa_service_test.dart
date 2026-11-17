import 'dart:convert';

import 'package:lab6_crypto/lab6_crypto.dart';
import 'package:test/test.dart';

void main() {
  final service = RsaService();
  late RsaKeyPair keys;

  setUpAll(() {
    keys = service.generateCryptoKeys();
  });

  test('Generates valid RSA key pair', () {
    expect(base64Decode(keys.publicKey), isNotEmpty);
    expect(base64Decode(keys.privateKey), isNotEmpty);
  });

  test('Encrypts and decrypts message', () {
    const message = 'Hello, Server!';

    final encrypted = service.encrypt(keys.publicKey, message);
    final decrypted = service.decrypt(keys.privateKey, encrypted);

    expect(encrypted, isNot(equals(message)));
    expect(decrypted, equals(message));
  });

  test('Supports UTF-8 messages', () {
    const message = 'Привіт, сервер! 🔐';

    final encrypted = service.encrypt(keys.publicKey, message);
    final decrypted = service.decrypt(keys.privateKey, encrypted);

    expect(decrypted, equals(message));
  });

  test('Rejects messages exceeding RSA block size', () {
    final message = 'A' * 300;

    expect(() => service.encrypt(keys.publicKey, message), throwsArgumentError);
  });
}
