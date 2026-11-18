import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:karazin_networks_server/repositories/crypto_repository.dart';
import 'package:karazin_networks_server/utils/json_response.dart';
import 'package:shelf/shelf.dart';

class CryptoKeysController {
  CryptoKeysController({required this._rsaService, required this._cryptoRepository});

  final RsaService _rsaService;
  final CryptoRepository _cryptoRepository;

  Response generateRsaKeyPair(Request request) {
    try {
      final keys = _rsaService.generateCryptoKeys();
      final id = _cryptoRepository.save(keys);

      return jsonResponse(200, {'id': id});
    } catch (_) {
      return jsonResponse(400, {'error': 'Failed to generate RSA keys'});
    }
  }

  Response getRsaPublicKey(Request request, String id) {
    final keyId = int.tryParse(id);

    if (keyId == null) {
      return jsonResponse(400, {'error': 'Invalid RSA key ID'});
    }

    final keys = _cryptoRepository.getById(keyId);

    if (keys == null) {
      return jsonResponse(404, {'error': 'RSA key not found'});
    }

    return Response.ok(keys.publicKey, headers: {'content-type': 'text/plain; charset=utf-8'});
  }
}
