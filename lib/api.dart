
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

enum AdminErrorKind { offline, slow, server, access, notFound, unknown }

class AdminException implements Exception {
  final String message;
  final AdminErrorKind kind;

  const AdminException(this.message, {this.kind = AdminErrorKind.unknown});

  @override
  String toString() => message;

  bool get retryable =>
      kind == AdminErrorKind.offline || kind == AdminErrorKind.slow;
}

String errText(Object e) =>
    e is AdminException ? e.message : 'حدث خطأ غير متوقع. حاولي مرة أخرى.';

List<Map<String, dynamic>> rowsOf(Map<String, dynamic> r) {
  final raw = r['data'];
  if (raw is! List) return [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

class Stats {
  final Map<String, int> counts;
  final int unreadShares;

  const Stats({required this.counts, required this.unreadShares});

  int count(String key) => counts[key] ?? 0;
}

class AdminState {
  AdminState._();
  static final ValueNotifier<int> unread = ValueNotifier<int>(0);
}

class AdminApi {
  AdminApi._();
  static final AdminApi instance = AdminApi._();

  String _password = '';

  void setPassword(String value) => _password = value;
  void clear() => _password = '';


  Future<Map<String, dynamic>> _call(
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 45),
    bool idempotent = false,
  }) async {
    if (!AdminConfig.isConfigured) {
      throw const AdminException(
        'لم يتم ضبط رابط Apps Script في الملف lib/config.dart',
        kind: AdminErrorKind.notFound,
      );
    }

    final attempts = idempotent ? 3 : 1;
    AdminException? last;

    for (var i = 0; i < attempts; i++) {
      // فاصل متدرّج حتى لا نزعج الخادم
      if (i > 0) await Future<void>.delayed(Duration(milliseconds: 900 * i));
      try {
        return await _once(body, timeout, idempotent: idempotent);
      } on AdminException catch (e) {
        last = e;
        if (!e.retryable || i == attempts - 1) rethrow;
      }
    }
    throw last ?? const AdminException('حدث خطأ غير متوقع. حاولي مرة أخرى.');
  }

 
  Future<Map<String, dynamic>> _once(
    Map<String, dynamic> body,
    Duration timeout, {
    required bool idempotent,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(AdminConfig.scriptUrl),
            // text/plain يتفادى preflight (Apps Script لا يدعمه)
            headers: const {'Content-Type': 'text/plain;charset=utf-8'},
            body: jsonEncode({...body, 'key': _password}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw AdminException(_slowMessage(idempotent),
          kind: AdminErrorKind.slow);
    } on http.ClientException catch (e) {
      // على الويب قد يكون سببه الشبكة أو CORS — لا نجزم بانقطاع النت.
      throw AdminException(
        'تعذّر الوصول إلى الخادم${_shorten(' ($e)')}. '
        'تحققي من الشبكة ثم أعيدي المحاولة.',
        kind: AdminErrorKind.offline,
      );
    } catch (_) {
      throw AdminException(_offlineMessage(idempotent),
          kind: AdminErrorKind.offline);
    }

    final text = _bodyText(res);
    final looksHtml = text.trimLeft().startsWith('<');

    if (res.statusCode >= 300 && res.statusCode < 400) {
      throw const AdminException(
        'الطلب مُحوَّل إلى صفحة دخول. تأكدي أن النشر مضبوط على '
        '«أي شخص» من Deploy ثم Manage deployments.',
        kind: AdminErrorKind.access,
      );
    }

    if (res.statusCode != 200) {
      throw await _httpError(res.statusCode, looksHtml, idempotent);
    }

    if (looksHtml) {
      // وصلتنا استجابة فعلاً → الاتصال قائم، المشكل في الرابط أو النشر.
      throw const AdminException(
        'وصلنا رداً لكنه ليس بيانات. تأكدي أن نشر آخر تحديث (New version) '
        'ومن ضبط الوصول على «أي شخص».',
        kind: AdminErrorKind.access,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const AdminException(
        'الرد ليس JSON صحيحاً. غالباً الكاش مكسور أو النشر قديم — أعيدي نشر '
        'آخر تحديث (New version) ثم حاولي مجدداً.',
        kind: AdminErrorKind.server,
      );
    }

    if (decoded is! Map) {
      // نص بدل كائن = كاش مكسور على السيرفر (مثل "[object Object]")
      throw AdminException(
        'رد غير متوقع من الخادم: "${_shorten(text)}". '
        'شغّلي clearCache من محرر Apps Script ثم أعيدي نشر آخر تحديث.',
        kind: AdminErrorKind.server,
      );
    }

    final map = Map<String, dynamic>.from(decoded);
    final err = map['error'];
    if (err != null) {
      final m = err.toString();
      if (m == 'UNAUTHORIZED') {
        throw const AdminException('كلمة السر غير صحيحة.',
            kind: AdminErrorKind.access);
      }
      throw AdminException(m);
    }
    return map;
  }


  String _slowMessage(bool idempotent) => idempotent
      ? 'الإنترنت بطيء جداً وانتهت المهلة. تحققي من الشبكة ثم أعيدي المحاولة.'
      : 'الإنترنت بطيء جداً وانتهت المهلة. تأكدي هل حُفظت البيانات قبل '
          'إعادة المحاولة حتى لا يتكرر الإرسال.';

  String _offlineMessage(bool idempotent) => idempotent
      ? 'تعذّر الوصول إلى الخادم. تحققي من الشبكة ثم أعيدي المحاولة.'
      : 'تعذّر الوصول إلى الخادم. تأكدي هل حُفظت البيانات قبل '
          'إعادة المحاولة حتى لا يتكرر الإرسال.';

 
  Future<AdminException> _httpError(
    int code,
    bool looksHtml,
    bool idempotent,
  ) async {
    if (code == 401 || code == 403) {
      return const AdminException(
        'الوصول مرفوض. تأكدي أن «من يمكنه الوصول» = «أي شخص».',
        kind: AdminErrorKind.access,
      );
    }
    if (code == 429) {
      return const AdminException(
        'طلبات كثيرة في وقت قصير. انتظري قليلاً ثم أعيدي المحاولة.',
        kind: AdminErrorKind.server,
      );
    }
    if (code >= 500) {
      return const AdminException(
        'الخادم مشغول حالياً. حاولي بعد قليل.',
        kind: AdminErrorKind.server,
      );
    }
    return const AdminException(
      'تعذّر الوصول إلى الخدمة. تأكدي من صحة الرابط ومن نشر آخر تحديث، '
      'ثم أعيدي المحاولة.',
      kind: AdminErrorKind.notFound,
    );
  }

  String _shorten(String s) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length <= 60 ? t : '${t.substring(0, 60)}…';
  }

  String _bodyText(http.Response res) {
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return res.body;
    }
  }

  Future<void> ping() async {
    await _call(
      {'action': 'ping'},
      timeout: const Duration(seconds: 30),
      idempotent: true,
    );
  }

  Future<Stats> stats() async {
    final r = await _call({'action': 'stats'}, idempotent: true);
    final raw = Map<String, dynamic>.from((r['counts'] as Map?) ?? {});
    final counts = raw.map((k, v) => MapEntry(k, int.tryParse('$v') ?? 0));
    final unread = int.tryParse('${r['unread_shares']}') ?? 0;
    AdminState.unread.value = unread;
    return Stats(counts: counts, unreadShares: unread);
  }

  Future<Map<String, dynamic>> list(
    String type, {
    int page = 1,
    int limit = 10,
    String? storyId,
  }) {
    return _call(
      {
        'action': 'list',
        'type': type,
        'page': page,
        'limit': limit,
        'story_id': ?storyId,
      },
      idempotent: true,
    );
  }

  Future<List<Map<String, dynamic>>> listAll(String type,
      {String? storyId}) async {
    return rowsOf(await list(type, storyId: storyId));
  }

  Future<void> add(String type, Map<String, dynamic> data) async {
    await _call({'action': 'add', 'type': type, 'data': data});
  }

  Future<void> update(String type, String id, Map<String, dynamic> data) async {
    await _call({'action': 'update', 'type': type, 'id': id, 'data': data},
        idempotent: true);
  }

  Future<void> delete(String type, String id) async {
    await _call({'action': 'delete', 'type': type, 'id': id},
        idempotent: true);
  }

  Future<void> markRead(String id, {bool read = true}) async {
    await _call({'action': 'mark_read', 'id': id, 'read': read},
        idempotent: true);
  }

  Future<String> uploadImage(Uint8List bytes) async {
    final r = await _call(
      {
        'action': 'upload_image',
        'mime': _sniffMime(bytes),
        'data': base64Encode(bytes),
      },
      timeout: const Duration(seconds: 120),
    );
    final url = r['url']?.toString() ?? '';
    if (url.isEmpty) throw const AdminException('فشل رفع الصورة.');
    return url;
  }

  String _sniffMime(Uint8List b) {
    if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50) return 'image/png';
    if (b.length > 3 && b[0] == 0x47 && b[1] == 0x49) return 'image/gif';
    if (b.length > 12 && b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}