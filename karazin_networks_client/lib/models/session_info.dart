class SessionInfo {
  const SessionInfo({
    required this.sessionId,
    required this.isValid,
    required this.expiresAt,
  });

  final String sessionId;
  final bool isValid;
  final DateTime expiresAt;

  factory SessionInfo.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid session information');
    }

    final sessionId = json['sessionId'];
    final isValid = json['isValid'];
    final expiresAt = json['expiresAt'];
    if (sessionId is! String ||
        sessionId.isEmpty ||
        isValid is! bool ||
        expiresAt is! String) {
      throw const FormatException('Invalid session information');
    }

    final expiration = DateTime.tryParse(expiresAt);
    if (expiration == null || !expiration.isUtc) {
      throw const FormatException('Invalid session expiration');
    }

    return SessionInfo(
      sessionId: sessionId,
      isValid: isValid,
      expiresAt: expiration,
    );
  }
}
