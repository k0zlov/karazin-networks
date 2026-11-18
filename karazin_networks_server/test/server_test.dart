import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:test/test.dart';

void main() {
  const cryptoKeysPath = '/api/crypto-keys';
  const sessionsPath = '/api/sessions';
  const messagesPath = '/api/messages';

  final client = http.Client();
  final rsaService = RsaService();
  final aesService = AesService();
  final hashService = HashService();
  Process? server;
  late Uri baseUrl;
  late int rsaId;
  late String publicKey;

  Future<http.Response> postJson(
    String path,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) {
    return client.post(
      baseUrl.resolve(path),
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode(body),
    );
  }

  Future<http.Response> createSession(String sessionId, AesKey aesKey) {
    final secret = jsonEncode({'key': aesKey.key, 'iv': aesKey.iv});
    return postJson(
      sessionsPath,
      {'encryptedKey': rsaService.encrypt(publicKey, secret)},
      headers: {'x-rsa-id': '$rsaId', 'x-session-id': sessionId},
    );
  }

  Future<http.Response> sendMessage(
    String sessionId,
    String cipherText, {
    String? hash,
  }) {
    return postJson(
      messagesPath,
      {'cipherText': cipherText, 'hash': hash},
      headers: {'x-session-id': sessionId},
    );
  }

  setUpAll(() async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['--suppress-analytics', 'run', 'bin/server.dart'],
      environment: {'PORT': '0'},
    );
    server = process;
    final stderr = process.stderr.transform(utf8.decoder).join();
    const startupPrefix = 'Server running at ';
    final startupLine = await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream()
        .firstWhere((line) => line.startsWith(startupPrefix), orElse: () => '')
        .timeout(const Duration(seconds: 20));
    if (startupLine.isEmpty) {
      throw StateError('Server failed to start: ${await stderr}');
    }
    baseUrl = Uri.parse(startupLine.substring(startupPrefix.length))
        .replace(host: '127.0.0.1');

    final generated = await client.post(
      baseUrl.resolve('$cryptoKeysPath/generate/rsa-keys'),
    );
    expect(generated.statusCode, 200, reason: generated.body);
    final keyId = (jsonDecode(generated.body) as Map<String, dynamic>)['id'];
    expect(keyId, allOf(isA<int>(), greaterThan(0)));
    rsaId = keyId as int;

    final keyResponse = await client.get(
      baseUrl.resolve('$cryptoKeysPath/rsa-public-key/$rsaId'),
    );
    expect(keyResponse.statusCode, 200, reason: keyResponse.body);
    expect(keyResponse.headers['content-type'], startsWith('text/plain'));
    expect(base64Decode(keyResponse.body), isNotEmpty);
    publicKey = keyResponse.body;
  });

  tearDownAll(() async {
    client.close();
    final process = server;
    if (process != null) {
      process.kill();
      await process.exitCode;
    }
  });

  test('Returns 404 for an unmatched route', () async {
    final response = await client.get(baseUrl.resolve('/foobar'));
    expect(response.statusCode, 404);
  });

  test('Serves the OpenAPI specification and Swagger UI', () async {
    final specification = await client.get(baseUrl.resolve('/openapi.yaml'));
    expect(specification.statusCode, 200);
    expect(
      specification.headers['content-type'],
      startsWith('application/yaml'),
    );
    expect(specification.body, await File('openapi.yaml').readAsString());

    final docs = await client.get(baseUrl.resolve('/docs'));
    expect(docs.statusCode, 200);
    expect(docs.headers['content-type'], startsWith('text/html'));
    expect(docs.body, contains("url: '/openapi.yaml'"));
  });

  test('Rejects malformed and unknown RSA key IDs', () async {
    final malformed = await client.get(
      baseUrl.resolve('$cryptoKeysPath/rsa-public-key/abc'),
    );
    expectError(malformed, 400, 'Invalid RSA key ID');

    final unknown = await client.get(
      baseUrl.resolve('$cryptoKeysPath/rsa-public-key/-1'),
    );
    expectError(unknown, 404, 'RSA key not found');
  });

  test('Rejects session requests with a missing or unknown RSA ID', () async {
    const body = {'encryptedKey': 'unused'};
    const sessionId = 'unknown-rsa';

    final missing = await postJson(
      sessionsPath,
      body,
      headers: {'x-session-id': sessionId},
    );
    expectError(missing, 400, 'Invalid RSA ID or session ID');

    final unknown = await postJson(
      sessionsPath,
      body,
      headers: {'x-session-id': sessionId, 'x-rsa-id': '-1'},
    );
    expectError(unknown, 404, 'RSA key not found');
  });

  test(
    'Establishes a session and encrypts Unicode replies with fresh nonces',
    () async {
      const sessionId = 'round-trip';
      final aesKey = await aesService.generateSecretKey();
      final created = await createSession(sessionId, aesKey);
      expect(created.statusCode, 201, reason: created.body);
      expect(jsonDecode(created.body), {
        'sessionId': sessionId,
        'status': 'established',
      });

      const message = 'Привіт, сервере! 🔐';
      const replyPrefix = '$message | Received at ';
      final replyNonces = <String>{};
      for (var i = 0; i < 2; i++) {
        final encrypted = await aesService.encrypt(aesKey, message);
        final response = await sendMessage(
          sessionId,
          encrypted,
          hash: await hashService.sha256(message),
        );
        expect(response.statusCode, 200, reason: response.body);
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        expect(body['sessionId'], sessionId);

        final cipherText = body['cipherText'] as String;
        final reply = await aesService.decrypt(aesKey, cipherText);
        expect(reply, startsWith(replyPrefix));
        expect(
          DateTime.tryParse(reply.substring(replyPrefix.length))?.isUtc,
          isTrue,
        );
        replyNonces.add(base64Encode(base64Decode(cipherText).sublist(0, 12)));
      }
      expect(replyNonces, hasLength(2));
    },
  );

  test(
    'Rejects invalid AES key and IV lengths during session creation',
    () async {
      final valid = await aesService.generateSecretKey();
      for (final invalid in [
        AesKey(key: base64Encode(List.filled(31, 0)), iv: valid.iv),
        AesKey(key: valid.key, iv: base64Encode(List.filled(11, 0))),
      ]) {
        final response = await createSession('invalid-secret', invalid);
        expectError(response, 400, 'Invalid AES key or IV');
      }
    },
  );

  test('Rejects a duplicate session ID', () async {
    const sessionId = 'duplicate';
    final created = await createSession(
      sessionId,
      await aesService.generateSecretKey(),
    );
    expect(created.statusCode, 201, reason: created.body);

    final duplicate = await createSession(
      sessionId,
      await aesService.generateSecretKey(),
    );
    expectError(duplicate, 409, 'Session already exists');
  });

  test('Rejects messages with missing or unknown session IDs', () async {
    final missing = await postJson(messagesPath, {'cipherText': 'unused'});
    expectError(missing, 400, 'Missing session ID');

    final unknown = await sendMessage('unknown', 'unused');
    expectError(unknown, 404, 'Session not found');
  });

  test('Rejects a message with a modified AES-GCM tag', () async {
    const sessionId = 'tampered';
    final aesKey = await aesService.generateSecretKey();
    final created = await createSession(sessionId, aesKey);
    expect(created.statusCode, 201, reason: created.body);

    final bytes = base64Decode(await aesService.encrypt(aesKey, 'Hello'));
    bytes[bytes.length - 1] ^= 1;
    final response = await sendMessage(
      sessionId,
      base64Encode(bytes),
      hash: await hashService.sha256('Hello'),
    );
    expectError(response, 400, 'Invalid encrypted message');
  });

  test('Rejects a valid AES message with the wrong hash and keeps the session usable', () async {
    const sessionId = 'hash-mismatch';
    final aesKey = await aesService.generateSecretKey();
    expect((await createSession(sessionId, aesKey)).statusCode, 201);
    const message = '  Привіт, сервере! 🔐\nHello  ';
    final cipherText = await aesService.encrypt(aesKey, message);
    final wrongHash = await hashService.sha256('$message changed');
    final rejected = await sendMessage(sessionId, cipherText, hash: wrongHash);
    expectError(rejected, 422, 'Message hash mismatch');

    final accepted = await sendMessage(
      sessionId,
      cipherText,
      hash: await hashService.sha256(message),
    );
    expect(accepted.statusCode, 200, reason: accepted.body);
    final body = jsonDecode(accepted.body) as Map<String, dynamic>;
    expect(
      await aesService.decrypt(aesKey, body['cipherText'] as String),
      startsWith('$message | Received at '),
    );
  });

  test('Rejects missing and malformed hashes', () async {
    const sessionId = 'invalid-hash';
    final aesKey = await aesService.generateSecretKey();
    expect((await createSession(sessionId, aesKey)).statusCode, 201);
    final cipherText = await aesService.encrypt(aesKey, 'Hello');
    final missing = await postJson(
      messagesPath,
      {'cipherText': cipherText},
      headers: {'x-session-id': sessionId},
    );
    expectError(missing, 400, 'Invalid message hash');

    for (final hash in [
      null,
      '',
      'a' * 63,
      'a' * 65,
      'g' * 64,
      'A' * 64,
      123,
      <String>[],
    ]) {
      final response = await postJson(
        messagesPath,
        {'cipherText': cipherText, 'hash': hash},
        headers: {'x-session-id': sessionId},
      );
      expectError(response, 400, 'Invalid message hash');
    }
  });

  test('Accepts the independently known SHA-256 hash of abc', () async {
    const sessionId = 'known-hash';
    final aesKey = await aesService.generateSecretKey();
    expect((await createSession(sessionId, aesKey)).statusCode, 201);
    final cipherText = await aesService.encrypt(aesKey, 'abc');
    final response = await sendMessage(
      sessionId,
      cipherText,
      hash: 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(response.statusCode, 200, reason: response.body);
  });

  test(
    'Lists stored sessions through HTTP without exposing AES keys or IVs',
    () async {
      const sessionId = 'listed-over-http';
      final key = await aesService.generateSecretKey();
      expect((await createSession(sessionId, key)).statusCode, 201);
      final response = await client.get(baseUrl.resolve(sessionsPath));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], startsWith('application/json'));
      final sessions = jsonDecode(response.body) as List<dynamic>;
      final session = sessions.singleWhere(
        (session) => session['sessionId'] == sessionId,
      ) as Map<String, dynamic>;
      expect(
        session.keys,
        unorderedEquals(['sessionId', 'isValid', 'expiresAt']),
      );
      expect(session['isValid'], isTrue);
      expect(DateTime.parse(session['expiresAt'] as String).isUtc, isTrue);
      expect(response.body, isNot(contains(key.key)));
      expect(response.body, isNot(contains(key.iv)));
    },
  );

  test('Allows browser preflight for session and message requests', () async {
    const origin = 'http://localhost:8081';
    for (final (path, requestedHeaders) in [
      (sessionsPath, ['content-type', 'x-rsa-id', 'x-session-id']),
      (messagesPath, ['content-type', 'x-session-id']),
    ]) {
      final request = http.Request('OPTIONS', baseUrl.resolve(path));
      request.headers.addAll({
        'origin': origin,
        'access-control-request-method': 'POST',
        'access-control-request-headers': requestedHeaders.join(', '),
      });
      final response = await http.Response.fromStream(
        await client.send(request),
      );
      expect(response.statusCode, 200, reason: response.body);
      expect(response.headers['access-control-allow-origin'], origin);
      expect(
        response.headers['access-control-allow-methods']?.split(','),
        contains('POST'),
      );
      final allowedHeaders = response.headers['access-control-allow-headers']
          ?.toLowerCase()
          .split(',')
          .map((header) => header.trim());
      expect(allowedHeaders, containsAll(requestedHeaders));
    }
  });
}

void expectError(http.Response response, int statusCode, String error) {
  expect(response.statusCode, statusCode, reason: response.body);
  expect(jsonDecode(response.body), {'error': error});
}
