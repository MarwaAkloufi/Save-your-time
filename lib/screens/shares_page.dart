import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class SharesPage extends StatefulWidget {
  const SharesPage({super.key});

  @override
  State<SharesPage> createState() => _SharesPageState();
}

class _SharesPageState extends State<SharesPage> {
  final AdminApi _api = AdminApi.instance;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isRead(Map<String, dynamic> it) => s(it, 'read').isNotEmpty;

  void _syncUnread() {
    AdminState.unread.value = _items.where((e) => !_isRead(e)).length;
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await _api.listAll('share');
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
        _error = null;
      });
      _syncUnread();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errText(e);
        _loading = false;
      });
    }
  }

  Future<void> _toggleRead(Map<String, dynamic> it) async {
    final newRead = !_isRead(it);
    try {
      await _api.markRead(s(it, 'id'), read: newRead);
      if (!mounted) return;
      setState(() => it['read'] = newRead ? '1' : '');
      _syncUnread();
    } catch (e) {
      if (!mounted) return;
      showMsg(context, errText(e), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> it) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف الفكرة',
      message: 'هل تريدين حذف هذه الرسالة نهائياً؟',
    );
    if (!ok) return;
    try {
      await _api.delete('share', s(it, 'id'));
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => s(e, 'id') == s(it, 'id')));
      _syncUnread();
      showMsg(context, 'تم الحذف');
    } catch (e) {
      if (!mounted) return;
      showMsg(context, errText(e), error: true);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showMsg(context, 'تم النسخ');
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: RefreshIndicator(
        color: C.ideas,
        onRefresh: () => _load(spinner: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              title: 'أفكار المستخدمين',
              subtitle: 'الرسائل التي أرسلها المستخدمون من «شاركنا بمعلومة»',
              icon: Icons.edit_note_rounded,
              color: C.ideas,
              bgColor: C.ideasBg,
            ),
            if (_loading)
              const LoadingView()
            else if (_error != null)
              ErrorView(message: _error!, onRetry: _load)
            else if (_items.isEmpty)
              EmptyView(
                  icon: Icons.inbox_outlined,
                  text: 'لم يصل أي شيء من المستخدمين بعد.',
                  color: C.ideas)
            else
              for (final it in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdminCard(
                    borderColor: _isRead(it) ? null : C.ideas.withValues(alpha: 0.6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            if (!_isRead(it))
                              Container(
                                margin: const EdgeInsetsDirectional.only(end: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: C.ideasBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('جديدة',
                                    style: TextStyle(
                                        color: C.ideas,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13)),
                              ),
                            Text(fmtDate(s(it, 'created_at')),
                                style: const TextStyle(
                                    fontSize: 13, color: C.textSoft)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(s(it, 'content'),
                            style: const TextStyle(fontSize: 18, height: 1.7)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _toggleRead(it),
                              icon: Icon(
                                  _isRead(it)
                                      ? Icons.mark_email_unread_outlined
                                      : Icons.done_all_rounded,
                                  size: 20),
                              label: Text(_isRead(it)
                                  ? 'تعليم كغير مقروءة'
                                  : 'تمت القراءة'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _copy(s(it, 'content')),
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              label: const Text('نسخ'),
                            ),
                            DeleteButton(onPressed: () => _delete(it)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
