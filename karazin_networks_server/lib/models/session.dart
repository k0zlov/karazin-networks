import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';

class Session {
  const Session({
    required this.id,
    required this.aesKey,
    required this.expiresAt,
  });

  final String id;
  final AesKey aesKey;
  final DateTime expiresAt;
}
