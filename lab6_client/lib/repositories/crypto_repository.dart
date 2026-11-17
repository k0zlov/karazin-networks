import 'package:lab6_client/network/api_routes.dart';
import 'package:lab6_client/network/network.dart';

class CryptoRepository {
  CryptoRepository(this._network);

  final Network _network;

  Future<int> generateRsaKeys() async {
    final response = await _network.post<Object?>(ApiRoutes.generateRsaKeys);
    if (response case {'id': final int id} when id > 0) {
      return id;
    }
    throw const FormatException('Invalid RSA key ID');
  }

  Future<String> getRsaPublicKey(int rsaId) async {
    final key = await _network.get<String>(ApiRoutes.rsaPublicKey(rsaId));

    if (key.trim().isEmpty) {
      throw const FormatException('Missing RSA public key');
    }

    return key.trim();
  }

  Future<void> createSession({required int rsaId, required String sessionId, required String encryptedKey}) async {
    final response = await _network.post<Object?>(
      ApiRoutes.sessions,
      headers: {'x-rsa-id': rsaId.toString(), 'x-session-id': sessionId},
      data: {'encryptedKey': encryptedKey},
    );
    if (response case {'sessionId': final String confirmedId, 'status': 'established'} when confirmedId == sessionId) {
      return;
    }

    throw const FormatException('Invalid session confirmation');
  }

  Future<String> sendMessage({required String sessionId, required String cipherText}) async {
    final response = await _network.post<Object?>(
      ApiRoutes.messages,
      headers: {'x-session-id': sessionId},
      data: {'cipherText': cipherText},
    );

    if (response case {'cipherText': final String encryptedReply} when encryptedReply.isNotEmpty) {
      return encryptedReply;
    }

    throw const FormatException('Missing encrypted reply');
  }
}
