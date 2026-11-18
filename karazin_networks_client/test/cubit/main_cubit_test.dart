import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karazin_networks_client/cubit/main_cubit.dart';
import 'package:karazin_networks_client/repositories/crypto_repository.dart';
import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';

class FakeCryptoRepository extends Fake implements CryptoRepository {
  FakeCryptoRepository(this.keys, this.rsaService, this.aesService);

  final RsaKeyPair keys;
  final RsaService rsaService;
  final AesService aesService;
  final sessions = <String, AesKey>{};
  final messages = <({String sessionId, String text, String cipherText})>[];
  final messageStatuses = <int>[];
  int generatedKeys = 0;
  int createdSessions = 0;
  Object? sessionError;
  Future<void>? sessionGate;
  Future<void>? messageGate;
  Completer<void>? sessionStarted;
  Completer<void>? messageStarted;

  @override
  Future<int> generateRsaKeys() async => ++generatedKeys;

  @override
  Future<String> getRsaPublicKey(int rsaId) async => keys.publicKey;

  @override
  Future<void> createSession({
    required int rsaId,
    required String sessionId,
    required String encryptedKey,
  }) async {
    createdSessions++;
    if (sessionStarted case final started? when !started.isCompleted) {
      started.complete();
    }
    await sessionGate;
    if (sessionError case final error?) throw error;

    final secret = jsonDecode(
      rsaService.decrypt(keys.privateKey, encryptedKey),
    ) as Map<String, dynamic>;
    sessions[sessionId] = AesKey(
      key: secret['key'] as String,
      iv: secret['iv'] as String,
    );
  }

  @override
  Future<String> sendMessage({
    required String sessionId,
    required String cipherText,
  }) async {
    final key = sessions[sessionId]!;
    final text = await aesService.decrypt(key, cipherText);
    messages.add((sessionId: sessionId, text: text, cipherText: cipherText));
    if (messageStarted case final started? when !started.isCompleted) {
      started.complete();
    }
    await messageGate;
    final status = messageStatuses.isEmpty ? 200 : messageStatuses.removeAt(0);
    if (status != 200) throw httpError(status);
    return aesService.encrypt(key, 'Server reply: $text');
  }
}

DioException httpError(int status) {
  final request = RequestOptions(path: '/api/messages');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: request,
    response: Response(requestOptions: request, statusCode: status),
  );
}

void main() {
  final rsaService = RsaService();
  final aesService = AesService();
  late RsaKeyPair keys;
  late FakeCryptoRepository repository;
  late MainCubit cubit;

  setUpAll(() => keys = rsaService.generateCryptoKeys());

  setUp(() {
    repository = FakeCryptoRepository(keys, rsaService, aesService);
    cubit = MainCubit(
      repository: repository,
      rsaService: rsaService,
      aesService: aesService,
    );
  });

  tearDown(() => cubit.close());

  test(
    'Stores the draft and decrypted reply and ignores duplicate sends',
    () async {
      await cubit.connect();
      final gate = Completer<void>();
      repository.messageGate = gate.future;
      repository.messageStarted = Completer<void>();
      cubit.changeMessage('Hello');
      final sending = cubit.sendMessage();
      expect(cubit.state.isSending, isTrue);
      await cubit.sendMessage();
      await repository.messageStarted!.future;
      gate.complete();
      await sending;

      expect(repository.messages, hasLength(1));
      expect(cubit.state.message, 'Hello');
      expect(cubit.state.reply, 'Server reply: Hello');
      expect(cubit.state.isSending, isFalse);
    },
  );

  test(
    'Clears a missing session and allows reconnecting with the draft',
    () async {
      await cubit.connect();
      final oldId = cubit.state.session!.id;
      repository.messageStatuses.add(404);
      cubit.changeMessage('Hello');
      await cubit.sendMessage();

      expect(cubit.state.session, isNull);
      expect(cubit.state.isSending, isFalse);
      expect(
        cubit.state.sessionError,
        'The session has ended. Reconnect to continue.',
      );
      expect(repository.createdSessions, 1);
      await cubit.connect();

      expect(cubit.state.isConnected, isTrue);
      expect(cubit.state.session!.id, isNot(oldId));
      expect(cubit.state.sessionError, isEmpty);
      expect(cubit.state.message, 'Hello');
    },
  );

  test(
    'Disposing during a connection prevents further state emissions',
    () async {
      final gate = Completer<void>();
      repository.sessionGate = gate.future;
      final connecting = cubit.connect();
      await cubit.close();
      gate.complete();
      await connecting;

      expect(cubit.isClosed, isTrue);
      expect(cubit.state.isConnected, isFalse);
    },
  );

  test(
    'Renews on 440 and re-encrypts the exact original text with a new key',
    () async {
      await cubit.connect();
      repository.messageStatuses.addAll([440, 200]);
      const message = '  Привіт, сервере! 🔐\nHello  ';
      cubit.changeMessage(message);
      await cubit.sendMessage();

      expect(repository.messages, hasLength(2));
      final first = repository.messages.first;
      final retry = repository.messages.last;
      expect(first.text, message);
      expect(retry.text, message);
      expect(retry.sessionId, isNot(first.sessionId));
      expect(
        repository.sessions[retry.sessionId]!.key,
        isNot(repository.sessions[first.sessionId]!.key),
      );
      expect(retry.cipherText, isNot(first.cipherText));
      expect(repository.generatedKeys, 2);
      expect(repository.createdSessions, 2);
      expect(cubit.state.reply, 'Server reply: $message');
      expect(cubit.state.message, message);
      expect(cubit.state.isSending, isFalse);
    },
  );

  test(
    'Stops after the second 440 and preserves the draft for manual reconnect',
    () async {
      await cubit.connect();
      repository.messageStatuses.addAll([440, 440]);
      cubit.changeMessage('Keep me');
      await cubit.sendMessage();

      expect(repository.messages, hasLength(2));
      expect(repository.createdSessions, 2);
      expect(cubit.state.session, isNull);
      expect(cubit.state.message, 'Keep me');
      expect(cubit.state.isSending, isFalse);
      expect(
        cubit.state.sessionError,
        'The session has ended. Reconnect to continue.',
      );

      await cubit.connect();
      await cubit.sendMessage();
      expect(repository.messages, hasLength(3));
      expect(cubit.state.reply, 'Server reply: Keep me');
    },
  );

  test('Preserves the draft when session renewal fails', () async {
    await cubit.connect();
    repository.messageStatuses.add(440);
    repository.sessionError = httpError(500);
    cubit.changeMessage('Keep after failure');
    await cubit.sendMessage();

    expect(repository.messages, hasLength(1));
    expect(repository.createdSessions, 2);
    expect(cubit.state.session, isNull);
    expect(cubit.state.message, 'Keep after failure');
    expect(cubit.state.isSending, isFalse);
    expect(cubit.state.isConnecting, isFalse);
    expect(
      cubit.state.sessionError,
      'Could not establish a session (HTTP 500).',
    );
  });

  for (final status in [400, 500]) {
    test('Does not renew or retry HTTP $status', () async {
      await cubit.connect();
      repository.messageStatuses.add(status);
      cubit.changeMessage('Keep on error');
      await cubit.sendMessage();

      expect(repository.messages, hasLength(1));
      expect(repository.createdSessions, 1);
      expect(cubit.state.message, 'Keep on error');
      expect(cubit.state.isSending, isFalse);
      expect(
        cubit.state.messageError,
        'Could not exchange a message (HTTP $status).',
      );
    });
  }

  test(
    'Stops and keeps the draft when the retry fails with HTTP 500',
    () async {
      await cubit.connect();
      repository.messageStatuses.addAll([440, 500]);
      cubit.changeMessage('Retry failure');
      await cubit.sendMessage();

      expect(repository.messages, hasLength(2));
      expect(repository.createdSessions, 2);
      expect(cubit.state.message, 'Retry failure');
      expect(cubit.state.isSending, isFalse);
      expect(
        cubit.state.messageError,
        'Could not exchange a message (HTTP 500).',
      );
    },
  );

  test(
    'Blocks duplicate sends during renewal and preserves later draft edits',
    () async {
      await cubit.connect();
      final gate = Completer<void>();
      repository.sessionGate = gate.future;
      repository.sessionStarted = Completer<void>();
      repository.messageStatuses.add(440);
      cubit.changeMessage('Original message');
      final sending = cubit.sendMessage();
      await repository.sessionStarted!.future;

      expect(cubit.state.isConnecting, isTrue);
      expect(cubit.state.isSending, isTrue);
      expect(cubit.state.canSend, isFalse);
      cubit.changeMessage('Later draft');
      await cubit.sendMessage();
      gate.complete();
      await sending;

      expect(repository.messages.map((message) => message.text), [
        'Original message',
        'Original message',
      ]);
      expect(repository.createdSessions, 2);
      expect(cubit.state.message, 'Later draft');
      expect(cubit.state.reply, 'Server reply: Original message');
    },
  );

  test('Disposing during renewal prevents the retry', () async {
    await cubit.connect();
    final gate = Completer<void>();
    repository.sessionGate = gate.future;
    repository.sessionStarted = Completer<void>();
    repository.messageStatuses.add(440);
    cubit.changeMessage('Hello');
    final sending = cubit.sendMessage();
    await repository.sessionStarted!.future;
    await cubit.close();
    gate.complete();
    await sending;

    expect(repository.messages, hasLength(1));
    expect(cubit.isClosed, isTrue);
  });

  test('Disposing while waiting for 440 prevents renewal', () async {
    await cubit.connect();
    final gate = Completer<void>();
    repository.messageGate = gate.future;
    repository.messageStarted = Completer<void>();
    repository.messageStatuses.add(440);
    cubit.changeMessage('Hello');
    final sending = cubit.sendMessage();
    await repository.messageStarted!.future;
    await cubit.close();
    gate.complete();
    await sending;

    expect(repository.messages, hasLength(1));
    expect(repository.createdSessions, 1);
    expect(cubit.isClosed, isTrue);
  });
}
