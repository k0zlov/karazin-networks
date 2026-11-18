import 'package:flutter_test/flutter_test.dart';
import 'package:karazin_networks_client/network/api_routes.dart';
import 'package:karazin_networks_client/network/network.dart';
import 'package:karazin_networks_client/repositories/crypto_repository.dart';

class RecordingNetwork extends Fake implements Network {
  String? path;
  Object? data;
  Map<String, String>? headers;

  @override
  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, String>? headers,
  }) async {
    this.path = path;
    this.data = data;
    this.headers = headers;
    return {'cipherText': 'encrypted reply'} as T;
  }
}

void main() {
  test('Sends the ciphertext and hash in the same message request', () async {
    final network = RecordingNetwork();
    final repository = CryptoRepository(network);
    final reply = await repository.sendMessage(
      sessionId: 'session',
      cipherText: 'encrypted message',
      hash: 'message hash',
    );

    expect(network.path, ApiRoutes.messages);
    expect(network.headers, {'x-session-id': 'session'});
    expect(network.data, {
      'cipherText': 'encrypted message',
      'hash': 'message hash',
    });
    expect(reply, 'encrypted reply');
  });
}
