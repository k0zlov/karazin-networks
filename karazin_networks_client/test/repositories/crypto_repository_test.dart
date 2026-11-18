import 'package:flutter_test/flutter_test.dart';
import 'package:karazin_networks_client/network/api_routes.dart';
import 'package:karazin_networks_client/network/network.dart';
import 'package:karazin_networks_client/repositories/crypto_repository.dart';

class RecordingNetwork extends Fake implements Network {
  String? path;
  Object? data;
  Map<String, String>? headers;
  Object? getResponse = <Object?>[];

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    this.path = path;
    return getResponse as T;
  }

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

  test('Loads session summaries and parses UTC expiration', () async {
    final network = RecordingNetwork();
    network.getResponse = [
      {
        'sessionId': 'valid',
        'isValid': true,
        'expiresAt': '2026-11-18T12:01:00Z',
      },
      {
        'sessionId': 'expired',
        'isValid': false,
        'expiresAt': '2026-11-18T11:01:00Z',
      },
    ];
    final sessions = await CryptoRepository(network).getSessions();
    expect(network.path, ApiRoutes.sessions);
    expect(sessions.map((session) => session.sessionId), ['valid', 'expired']);
    expect(sessions.map((session) => session.isValid), [true, false]);
    expect(sessions.first.expiresAt, DateTime.utc(2026, 11, 18, 12, 1));
    expect(sessions.first.expiresAt.isUtc, isTrue);
  });

  test('Accepts an empty sessions array', () async {
    expect(await CryptoRepository(RecordingNetwork()).getSessions(), isEmpty);
  });

  test('Rejects a malformed sessions response', () async {
    final network = RecordingNetwork();
    final repository = CryptoRepository(network);
    for (final response in [null, 'invalid', 42, <String, Object?>{}]) {
      network.getResponse = response;
      await expectLater(repository.getSessions(), throwsFormatException);
    }
  });

  test('Rejects invalid session fields and expiration values', () async {
    final network = RecordingNetwork();
    final repository = CryptoRepository(network);
    for (final session in [
      null,
      <String, Object?>{},
      {'sessionId': '', 'isValid': true, 'expiresAt': '2026-11-18T12:01:00Z'},
      {
        'sessionId': 'test',
        'isValid': 'true',
        'expiresAt': '2026-11-18T12:01:00Z',
      },
      {'sessionId': 'test', 'isValid': true, 'expiresAt': 'invalid'},
      {
        'sessionId': 'test',
        'isValid': true,
        'expiresAt': '2026-11-18T12:01:00',
      },
    ]) {
      network.getResponse = [session];
      await expectLater(repository.getSessions(), throwsFormatException);
    }
  });
}
