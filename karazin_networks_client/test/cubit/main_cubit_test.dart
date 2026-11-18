import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karazin_networks_client/cubit/main_cubit.dart';
import 'package:karazin_networks_client/repositories/crypto_repository.dart';
import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';

class FakeCryptoRepository extends Fake implements CryptoRepository {
  FakeCryptoRepository(this.publicKey);

  final String publicKey;
  int generatedKeys = 0;
  int createdSessions = 0;
  Future<void>? sessionGate;
  Future<String> Function()? reply;

  @override
  Future<int> generateRsaKeys() async => ++generatedKeys;

  @override
  Future<String> getRsaPublicKey(int rsaId) async => publicKey;

  @override
  Future<void> createSession({
    required int rsaId,
    required String sessionId,
    required String encryptedKey,
  }) async {
    createdSessions++;
    await sessionGate;
  }

  @override
  Future<String> sendMessage({
    required String sessionId,
    required String cipherText,
  }) async => await reply!();
}

void main() {
  final rsaService = RsaService();
  final aesService = AesService();
  late RsaKeyPair keys;
  late FakeCryptoRepository repository;
  late MainCubit cubit;

  setUpAll(() => keys = rsaService.generateCryptoKeys());

  setUp(() {
    repository = FakeCryptoRepository(keys.publicKey);
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
      final reply = Completer<String>();
      var sentMessages = 0;
      repository.reply = () {
        sentMessages++;
        return reply.future;
      };
      cubit.changeMessage('Hello');
      final first = cubit.sendMessage();
      expect(cubit.state.isSending, isTrue);
      await cubit.sendMessage();

      reply.complete(
        await aesService.encrypt(cubit.state.session!.key, 'Server reply'),
      );
      await first;

      expect(sentMessages, 1);
      expect(cubit.state.message, 'Hello');
      expect(cubit.state.reply, 'Server reply');
      expect(cubit.state.isSending, isFalse);
    },
  );

  test(
    'Clears a missing session and allows reconnecting with the draft',
    () async {
      await cubit.connect();
      final oldSessionId = cubit.state.session!.id;
      repository.reply = () async {
        final request = RequestOptions(path: '/api/messages');
        throw DioException.badResponse(
          statusCode: 404,
          requestOptions: request,
          response: Response(requestOptions: request, statusCode: 404),
        );
      };
      cubit.changeMessage('Hello');
      await cubit.sendMessage();

      expect(cubit.state.session, isNull);
      expect(cubit.state.isSending, isFalse);
      expect(
        cubit.state.sessionError,
        'The session has ended. Reconnect to continue.',
      );
      await cubit.connect();

      expect(cubit.state.isConnected, isTrue);
      expect(cubit.state.session!.id, isNot(oldSessionId));
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
}
