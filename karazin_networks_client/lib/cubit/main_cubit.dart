import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karazin_networks_client/cubit/main_state.dart';
import 'package:karazin_networks_client/repositories/crypto_repository.dart';
import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:uuid/uuid.dart';

class MainCubit extends Cubit<MainState> {
  MainCubit({
    required this._repository,
    required this._rsaService,
    required this._aesService,
    required this._hashService,
  }) : super(const MainState());

  final CryptoRepository _repository;
  final RsaService _rsaService;
  final AesService _aesService;
  final HashService _hashService;

  Future<void> connect() async {
    if (isClosed || state.isConnecting || state.isConnected) return;
    emit(state.copyWith(isConnecting: true, sessionError: ''));

    try {
      final rsaId = await _repository.generateRsaKeys();
      final publicKey = await _repository.getRsaPublicKey(rsaId);
      final aesKey = await _aesService.generateSecretKey();
      final sessionId = const Uuid().v4();
      final secret = jsonEncode({'key': aesKey.key, 'iv': aesKey.iv});
      final encryptedKey = _rsaService.encrypt(publicKey, secret);

      await _repository.createSession(
        rsaId: rsaId,
        sessionId: sessionId,
        encryptedKey: encryptedKey,
      );
      if (isClosed) return;

      emit(
        state.copyWith(
          session: (id: sessionId, key: aesKey),
          isConnecting: false,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isConnecting: false,
          sessionError: _describeError(error, 'Could not establish a session'),
        ),
      );
    }
  }

  void changeMessage(String message) {
    if (isClosed) return;
    emit(state.copyWith(message: message));
  }

  Future<void> sendMessage({bool corruptHash = false}) async {
    if (isClosed || !state.canSend) return;
    final session = state.session!;
    final message = state.message;
    emit(state.copyWith(isSending: true, reply: '', messageError: ''));

    try {
      var hash = await _hashService.sha256(message);
      if (corruptHash) {
        final firstCharacter = hash.startsWith('0') ? '1' : '0';
        hash = '$firstCharacter${hash.substring(1)}';
      }

      String reply;
      try {
        reply = await _exchangeMessage(session, message, hash);
      } on DioException catch (error) {
        if (error.response?.statusCode != 440) rethrow;
        if (isClosed) return;

        emit(state.copyWith(clearSession: true));
        await connect();
        if (isClosed || !state.isConnected) return;

        reply = await _exchangeMessage(state.session!, message, hash);
      }
      if (isClosed) return;

      emit(state.copyWith(reply: reply));
    } catch (error) {
      if (isClosed) return;

      if (error is DioException &&
          (error.response?.statusCode == 404 ||
              error.response?.statusCode == 440)) {
        emit(
          state.copyWith(
            clearSession: true,
            sessionError: 'The session has ended. Reconnect to continue.',
          ),
        );
      } else {
        emit(
          state.copyWith(
            messageError: _describeError(error, 'Could not exchange a message'),
          ),
        );
      }
    } finally {
      if (!isClosed) emit(state.copyWith(isSending: false));
    }
  }

  Future<String> _exchangeMessage(
    ({String id, AesKey key}) session,
    String message,
    String hash,
  ) async {
    final cipherText = await _aesService.encrypt(session.key, message);
    final encryptedReply = await _repository.sendMessage(
      sessionId: session.id,
      cipherText: cipherText,
      hash: hash,
    );
    return _aesService.decrypt(session.key, encryptedReply);
  }

  String _describeError(Object error, String fallback) {
    if (error is! DioException) return '$fallback.';

    final statusCode = error.response?.statusCode;
    if (statusCode == 422) return 'Message rejected: hash mismatch (HTTP 422).';

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'The server did not respond in time.',
      DioExceptionType.connectionError => 'Could not connect to the server.',
      _ => statusCode == null ? '$fallback.' : '$fallback (HTTP $statusCode).',
    };
  }
}
