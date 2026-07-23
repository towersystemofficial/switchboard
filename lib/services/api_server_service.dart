import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../models/member.dart';
import '../models/front_entry.dart';

/// A tiny read-only local HTTP API so an LLM or script can query this app's
/// data directly (current fronter, history, members, stats) instead of
/// needing raw file access. Bound to all interfaces on the local network
/// only -- there is no auth, so only enable this on networks you trust.
class ApiServerService {
  HttpServer? _server;

  /// Callbacks are supplied by the provider so this service never needs to
  /// know about ChangeNotifier / Flutter widget state directly.
  final List<Member> Function() getMembers;
  final List<FrontEntry> Function() getEntries;

  ApiServerService({required this.getMembers, required this.getEntries});

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  Future<void> start(int port) async {
    if (_server != null) await stop();
    final router = Router();

    router.get('/health', (Request req) => _json({'status': 'ok'}));

    router.get('/members', (Request req) {
      final members = getMembers();
      return _json(members.map((m) => m.toJson()).toList());
    });

    router.get('/members/<id>', (Request req, String id) {
      final members = getMembers();
      final match = members.where((m) => m.id == id);
      if (match.isEmpty) return _json({'error': 'not found'}, status: 404);
      return _json(match.first.toJson());
    });

    router.get('/fronters/current', (Request req) {
      final entries = getEntries();
      final members = getMembers();
      final active = entries.where((e) => e.isActive).toList();
      final result = active.map((entry) {
        final member = members.where((m) => m.id == entry.memberId);
        return {
          ...entry.toJson(),
          'memberName': member.isNotEmpty ? member.first.name : null,
        };
      }).toList();
      return _json({'current': result});
    });

    router.get('/fronters/history', (Request req) {
      final entries = getEntries();
      final members = {for (final m in getMembers()) m.id: m.name};
      final sorted = [...entries]..sort((a, b) => b.start.compareTo(a.start));
      return _json(sorted
          .map((e) => {...e.toJson(), 'memberName': members[e.memberId]})
          .toList());
    });

    router.get('/stats', (Request req) {
      final entries = getEntries();
      final members = getMembers();
      final counts = <String, int>{};
      final totalSeconds = <String, int>{};
      for (final e in entries) {
        counts[e.memberId] = (counts[e.memberId] ?? 0) + 1;
        totalSeconds[e.memberId] = (totalSeconds[e.memberId] ?? 0) + e.duration.inSeconds;
      }
      final stats = members.map((m) {
        final count = counts[m.id] ?? 0;
        final total = totalSeconds[m.id] ?? 0;
        return {
          'memberId': m.id,
          'memberName': m.name,
          'switchCount': count,
          'totalSeconds': total,
          'averageSeconds': count > 0 ? (total / count).round() : 0,
        };
      }).toList();
      return _json(stats);
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_errorHandlingMiddleware())
        .addHandler(router.call);
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Middleware _errorHandlingMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        try {
          return await innerHandler(request);
        } catch (e, st) {
          // ignore: avoid_print
          print('API error on ${request.url}: $e\n$st');
          return _json({'error': e.toString()}, status: 500);
        }
      };
    };
  }

  Response _json(Object data, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
