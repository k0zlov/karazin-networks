import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class HashService {
  final Sha256 _algorithm = Sha256();

  Future<String> sha256(String message) async {
    final hash = await _algorithm.hash(utf8.encode(message));
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
