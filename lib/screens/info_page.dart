import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final AdminApi _api = AdminApi.instance;
  final TextEditingController _text = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await _api.listAll('info');
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errText(e);
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final value = _text.text.trim();
    if (value.isEmpty) {
      showMsg(context, 'اكتبي المعلومة أولاً', error: true);
      return;
    }
    setState(() => _adding = true);
    try {
      await _api.add('info', {'content': value});
      if (!mounted) return;
      _text.clear();
      setState(() => _adding = false);
      showMsg(context, 'تمت إضافة المعلومة ✓');
      _load(spinner: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _adding = false);
      showMsg(context, errText(e), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> it) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف المعلومة',
      message: 'هل تريدين حذف هذه المعلومة نهائياً؟',
    );
    if (!ok) return;
    try {
      await _api.delete('info', s(it, 'id'));
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => s(e, 'id') == s(it, 'id')));
      showMsg(context, 'تم الحذف');
    } catch (e) {
      if (!mounted) return;
      showMsg(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: RefreshIndicator(
        color: C.info,
        onRefresh: () => _load(spinner: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SectionHeader(
              title: 'هل تعلم؟',
              subtitle: 'معلومات تظهر للمستخدمين بشكل عشوائي',
              icon: Icons.lightbulb_rounded,
              color: C.info,
              bgColor: C.infoBg,
            ),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _text,
                    enabled: !_adding,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1000,
                    style: const TextStyle(fontSize: 17, height: 1.6),
                    decoration: const InputDecoration(
                      labelText: 'معلومة جديدة',
                      hintText: 'مثال: العسل لا يفسد أبداً...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.info),
                      onPressed: _adding ? null : _add,
                      icon: _adding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: Colors.white))
                          : const Icon(Icons.add_rounded),
                      label: const Text('إضافة'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const LoadingView()
            else if (_error != null)
              ErrorView(message: _error!, onRetry: _load)
            else if (_items.isEmpty)
              const EmptyView(
                  icon: Icons.lightbulb_outline_rounded,
                  text: 'لا يوجد معلومات بعد.',
                  color: C.info)
            else
              for (final it in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AdminCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.lightbulb_outline_rounded,
                              color: C.info),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s(it, 'content'),
                                  style: const TextStyle(
                                      fontSize: 17, height: 1.7)),
                              const SizedBox(height: 4),
                              Text(fmtDate(s(it, 'created_at')),
                                  style: const TextStyle(
                                      fontSize: 13, color: C.textSoft)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'حذف',
                          onPressed: () => _delete(it),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: C.error),
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
