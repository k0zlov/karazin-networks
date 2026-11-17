import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:lab6_crypto/lab6_crypto.dart';

class AesService {
  final AesGcm _algorithm = AesGcm.with256bits();

  Future<AesKey> generateSecretKey() async {
    final secretKey = await _algorithm.newSecretKey();
    final keyBytes = await secretKey.extractBytes();
    final iv = _algorithm.newNonce();

    return AesKey(key: base64Encode(keyBytes), iv: base64Encode(iv));
  }

  Future<String> encrypt(AesKey aesKey, String plainText) async {
    final secretKey = _decodeKey(aesKey);

    final secretBox = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: secretKey,
      nonce: _algorithm.newNonce(),
    );

    return base64Encode(secretBox.concatenation());
  }

  Future<String> decrypt(AesKey aesKey, String cipherText) async {
    final secretKey = _decodeKey(aesKey);
    final encryptedBytes = base64Decode(cipherText);

    final nonceLength = _algorithm.nonceLength;
    final macLength = _algorithm.macAlgorithm.macLength;

    if (encryptedBytes.length < nonceLength + macLength) {
      throw const FormatException('Invalid encrypted message');
    }

    final secretBox = SecretBox.fromConcatenation(encryptedBytes, nonceLength: nonceLength, macLength: macLength);

    final decryptedBytes = await _algorithm.decrypt(secretBox, secretKey: secretKey);

    return utf8.decode(decryptedBytes);
  }

  SecretKey _decodeKey(AesKey aesKey) {
    final bytes = base64Decode(aesKey.key);

    if (bytes.length != 32) {
      throw ArgumentError('AES-256 key must contain 32 bytes');
    }

    return SecretKey(bytes);
  }
}
