import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

// Middleware CORS pour autoriser Flutter Web
Middleware _corsHeaders() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };

  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final response = await innerHandler(request);
      return response.change(headers: headers);
    };
  };
}

Response _jsonResponse(Map<String, dynamic> data, {int statusCode = 200}) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}

void main() async {
  final router = Router();

  // 1. Vérification de santé de la sonde
  router.get('/health', (Request req) {
    return _jsonResponse({'status': 'ok', 'probe': 'NetCheck Dart Backend'});
  });

  // 2. Sonde HTTP (contourne le CORS navigateur)
  router.post('/probe/http', (Request req) async {
    final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final url = payload['url']?.toString() ?? '';
    final stopwatch = Stopwatch()..start();

    try {
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      stopwatch.stop();
      return _jsonResponse({
        'online': resp.statusCode >= 200 && resp.statusCode < 400,
        'status_code': resp.statusCode,
        'latency_ms': stopwatch.elapsedMilliseconds,
        'headers': resp.headers,
        'error': null,
      });
    } catch (e) {
      stopwatch.stop();
      return _jsonResponse({
        'online': false,
        'status_code': null,
        'latency_ms': stopwatch.elapsedMilliseconds,
        'headers': {},
        'error': e.toString(),
      });
    }
  });

  // 3. Scanner de port TCP (SSH 22, PostgreSQL 5432, HTTPS 443...)
  router.post('/probe/tcp', (Request req) async {
    final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final rawHost = payload['host']?.toString() ?? '';
    final port = payload['port'] as int? ?? 80;
    final cleanHost = rawHost
        .trim()
        .replaceAll(RegExp(r'^https?://'), '')
        .split('/')
        .first;

    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        cleanHost,
        port,
        timeout: const Duration(seconds: 3),
      );
      stopwatch.stop();
      await socket.close();

      return _jsonResponse({
        'open': true,
        'host': cleanHost,
        'port': port,
        'latency_ms': stopwatch.elapsedMilliseconds,
        'error': null,
      });
    } catch (e) {
      stopwatch.stop();
      return _jsonResponse({
        'open': false,
        'host': cleanHost,
        'port': port,
        'latency_ms': stopwatch.elapsedMilliseconds,
        'error': 'Port $port fermé ou filtré sur $cleanHost',
      });
    }
  });

  // 4. Inspecteur de certificat SSL/TLS
  router.post('/probe/ssl', (Request req) async {
    final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final rawDomain = payload['domain']?.toString() ?? '';
    final cleanHost = rawDomain
        .trim()
        .replaceAll(RegExp(r'^https?://'), '')
        .split('/')
        .first;

    try {
      final socket = await SecureSocket.connect(
        cleanHost,
        443,
        timeout: const Duration(seconds: 5),
      );
      final cert = socket.peerCertificate;
      await socket.close();

      if (cert == null) {
        return _jsonResponse({
          'valid': false,
          'domain': cleanHost,
          'error': 'Aucun certificat présenté par le serveur.',
        });
      }

      final daysRemaining =
          cert.endValidity.difference(DateTime.now().toUtc()).inDays;
      return _jsonResponse({
        'valid': daysRemaining > 0,
        'domain': cleanHost,
        'issuer': cert.issuer,
        'expires_at': cert.endValidity.toIso8601String(),
        'days_remaining': daysRemaining,
        'error': null,
      });
    } catch (e) {
      return _jsonResponse({
        'valid': false,
        'domain': cleanHost,
        'error': 'Erreur SSL/TLS : $e',
      });
    }
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsHeaders())
      .addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8000');
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Sonde NetCheck (Dart) démarrée sur http://localhost:${server.port}');
}