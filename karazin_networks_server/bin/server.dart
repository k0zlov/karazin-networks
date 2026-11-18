import 'dart:io';

import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:karazin_networks_server/controllers/crypto_keys_controller.dart';

import 'package:karazin_networks_server/controllers/messages_controller.dart';
import 'package:karazin_networks_server/controllers/sessions_controller.dart';

import 'package:karazin_networks_server/repositories/crypto_repository.dart';
import 'package:karazin_networks_server/repositories/session_repository.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

Future<void> main() async {
  // Services
  final rsaService = RsaService();
  final aesService = AesService();
  final hashService = HashService();

  // Repositories
  final cryptoRepository = CryptoRepository();
  final sessionRepository = SessionRepository();

  // Controllers
  final cryptoController = CryptoKeysController(
    rsaService: rsaService,
    cryptoRepository: cryptoRepository,
  );

  final sessionsController = SessionsController(
    rsaService: rsaService,
    cryptoRepository: cryptoRepository,
    sessionRepository: sessionRepository,
  );

  final messagesController = MessagesController(
    aesService: aesService,
    hashService: hashService,
    sessionRepository: sessionRepository,
  );

  // Routes
  final openApi = await File.fromUri(Platform.script.resolve('../openapi.yaml'))
      .readAsString();
  final router = Router()
    ..get(
      '/openapi.yaml',
      (Request request) => Response.ok(
        openApi,
        headers: {'content-type': 'application/yaml; charset=utf-8'},
      ),
    )
    ..get(
      '/docs',
      (Request request) => Response.ok(
        _swaggerHtml,
        headers: {'content-type': 'text/html; charset=utf-8'},
      ),
    )
    ..post(
      '/api/crypto-keys/generate/rsa-keys',
      cryptoController.generateRsaKeyPair,
    )
    ..get(
      '/api/crypto-keys/rsa-public-key/<id>',
      cryptoController.getRsaPublicKey,
    )
    ..get('/api/sessions', sessionsController.getSessions)
    ..post('/api/sessions', sessionsController.createSession)
    ..post('/api/messages', messagesController.sendMessage);

  // Middleware
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(
        corsHeaders(
          headers: {
            ACCESS_CONTROL_ALLOW_HEADERS:
                'Origin, Content-Type, Accept, x-rsa-id, x-session-id',
          },
        ),
      )
      .addHandler(router.call);

  // Start server
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  stdout.writeln('Server running at http://localhost:${server.port}');
}

const _swaggerHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Karazin Networks API</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script>
    SwaggerUIBundle({url: '/openapi.yaml', dom_id: '#swagger-ui', validatorUrl: null});
  </script>
</body>
</html>
''';
