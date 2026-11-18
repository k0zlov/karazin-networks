import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';

class CryptoRepository {
  final Map<int, RsaKeyPair> _keys = {};
  int _nextId = 1;

  int save(RsaKeyPair keys) {
    final id = _nextId++;
    _keys[id] = keys;

    return id;
  }

  RsaKeyPair? getById(int id) => _keys[id];
}
