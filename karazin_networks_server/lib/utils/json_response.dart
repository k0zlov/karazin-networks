import 'dart:convert';

import 'package:shelf/shelf.dart';

Response jsonResponse(int statusCode, Object? data) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final decoded = jsonDecode(await request.readAsString());

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected JSON object');
  }

  return decoded;
}
