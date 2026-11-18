import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:pointycastle/export.dart';

class RsaService {
  RsaKeyPair generateCryptoKeys() {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);

    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    return RsaKeyPair(
      publicKey: base64Encode(CryptoUtils.encodeRSAPublicKeyToDERBytes(publicKey)),
      privateKey: base64Encode(CryptoUtils.encodeRSAPrivateKeyToDERBytes(privateKey)),
    );
  }

  String encrypt(String publicKey, String plainText) {
    final key = CryptoUtils.rsaPublicKeyFromDERBytes(base64Decode(publicKey));

    final cipher = OAEPEncoding.withSHA256(RSAEngine())..init(true, PublicKeyParameter<RSAPublicKey>(key));

    final bytes = Uint8List.fromList(utf8.encode(plainText));

    if (bytes.length > cipher.inputBlockSize) {
      throw ArgumentError('Message is too large for RSA encryption');
    }

    return base64Encode(cipher.process(bytes));
  }

  String decrypt(String privateKey, String cipherText) {
    final key = CryptoUtils.rsaPrivateKeyFromDERBytes(base64Decode(privateKey));

    final cipher = OAEPEncoding.withSHA256(RSAEngine())..init(false, PrivateKeyParameter<RSAPrivateKey>(key));

    final encryptedBytes = base64Decode(cipherText);
    final decryptedBytes = cipher.process(Uint8List.fromList(encryptedBytes));

    return utf8.decode(decryptedBytes);
  }
}
