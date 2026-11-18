import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:test/test.dart';

void main() {
  final service = HashService();

  test('Matches the SHA-256 empty string test vector', () async {
    expect(
      await service.sha256(''),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
  });

  test('Matches the SHA-256 abc test vector', () async {
    expect(
      await service.sha256('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('Hashes the exact UTF-8 text with whitespace and line breaks', () async {
    expect(
      await service.sha256('  Привіт, сервере! 🔐\nHello  '),
      '88ffffc0c5522227f71f9b0068a09a3fe402feb01000a8f033953605a2eb82ae',
    );
  });

  test('Produces distinct hashes when whitespace changes', () async {
    expect(
      await service.sha256(' Hello '),
      isNot(await service.sha256('Hello')),
    );
  });
}
