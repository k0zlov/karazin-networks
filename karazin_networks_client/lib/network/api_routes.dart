abstract final class ApiRoutes {
  static const String cryptoKeys = '/api/crypto-keys';

  static const String generateRsaKeys = '$cryptoKeys/generate/rsa-keys';

  static String rsaPublicKey(int id) => '$cryptoKeys/rsa-public-key/$id';

  static const String sessions = '/api/sessions';
  static const String messages = '/api/messages';
}
