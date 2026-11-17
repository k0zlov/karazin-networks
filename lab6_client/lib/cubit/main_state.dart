import 'package:lab6_crypto/lab6_crypto.dart';

class MainState {
  const MainState({
    this.session,
    this.isConnecting = false,
    this.isSending = false,
    this.message = '',
    this.reply = '',
    this.sessionError = '',
    this.messageError = '',
  });

  final ({String id, AesKey key})? session;
  final bool isConnecting;
  final bool isSending;
  final String message;
  final String reply;
  final String sessionError;
  final String messageError;

  bool get isConnected => session != null;
  bool get canSend => isConnected && !isSending && message.trim().isNotEmpty;

  MainState copyWith({
    ({String id, AesKey key})? session,
    bool clearSession = false,
    bool? isConnecting,
    bool? isSending,
    String? message,
    String? reply,
    String? sessionError,
    String? messageError,
  }) {
    return MainState(
      session: clearSession ? null : session ?? this.session,
      isConnecting: isConnecting ?? this.isConnecting,
      isSending: isSending ?? this.isSending,
      message: message ?? this.message,
      reply: reply ?? this.reply,
      sessionError: sessionError ?? this.sessionError,
      messageError: messageError ?? this.messageError,
    );
  }
}
