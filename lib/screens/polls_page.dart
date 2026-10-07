import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class PollsPage extends StatefulWidget {
  const PollsPage({super.key});

  @override
  State<PollsPage> createState() => _PollsPageState();
}

class _PollsPageState extends State<PollsPage> {
  final AdminApi _api = AdminApi.instance;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await _api.listAll('poll');
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

  Future<void> _openNew() async {
    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _NewPollDialog(),
    );
    if (added == true) {
      if (!mounted) return;
      showMsg(context, 'تمت إضافة الاستطلاع ✓');
      _load(spinner: false);
    }
  }

  Future<void> _delete(Map<String, dynamic> it) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف الاستطلاع',
      message: 'سيتم حذف الاستطلاع ونتائجه نهائياً. هل أنتِ متأكدة؟',
    );
    if (!ok) return;
    try {
      await _api.delete('poll', s(it, 'id'));
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => s(e, 'id') == s(it, 'id')));
      showMsg(context, 'تم حذف الاستطلاع');
    } catch (e) {
      if (!mounted) return;
      showMsg(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: RefreshIndicator(
        color: C.poll,
        onRefresh: () => _load(spinner: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              title: 'استطلاع رأي',
              subtitle: 'أسئلة يصوّت عليها المستخدمون',
              icon: Icons.how_to_vote_rounded,
              color: C.poll,
              bgColor: C.pollBg,
              action: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: C.poll),
                onPressed: _openNew,
                icon: const Icon(Icons.add_rounded),
                label: const Text('استطلاع جديد'),
              ),
            ),
            if (_loading)
              const LoadingView()
            else if (_error != null)
              ErrorView(message: _error!, onRetry: _load)
            else if (_items.isEmpty)
              const EmptyView(
                  icon: Icons.how_to_vote_outlined,
                  text: 'لا يوجد استطلاعات بعد.\nاضغطي «استطلاع جديد».',
                  color: C.poll)
            else
              for (final it in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PollCard(poll: it, onDelete: () => _delete(it)),
                ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  final Map<String, dynamic> poll;
  final VoidCallback onDelete;

  const _PollCard({required this.poll, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final options = ((poll['options'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final votes = options.map((o) => int.tryParse(s(o, 'votes')) ?? 0).toList();
    final total = votes.fold<int>(0, (a, b) => a + b);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s(poll, 'question'),
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w800, height: 1.5)),
          const SizedBox(height: 12),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(s(options[i], 'text'),
                            style: const TextStyle(fontSize: 16)),
                      ),
                      Text(
                        total == 0
                            ? '${votes[i]}'
                            : '${votes[i]}  (${(votes[i] * 100 / total).round()}%)',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: C.poll),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : votes[i] / total,
                      minHeight: 12,
                      backgroundColor: C.pollBg,
                      color: C.poll,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              DeleteButton(onPressed: onDelete),
              const Spacer(),
              Text('المجموع: $total صوت',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: C.textSoft)),
            ],
          ),
          const SizedBox(height: 4),
          Text(fmtDate(s(poll, 'created_at')),
              style: const TextStyle(fontSize: 13, color: C.textSoft)),
        ],
      ),
    );
  }
}

// ─── حوار استطلاع جديد ───
class _NewPollDialog extends StatefulWidget {
  const _NewPollDialog();

  @override
  State<_NewPollDialog> createState() => _NewPollDialogState();
}

class _NewPollDialogState extends State<_NewPollDialog> {
  static const int _minOptions = 2;
  static const int _maxOptions = 6;

  final TextEditingController _question = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= _maxOptions) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int i) {
    if (_options.length <= _minOptions) return;
    final c = _options.removeAt(i);
    setState(() {});
    c.dispose();
  }

  Future<void> _submit() async {
    final q = _question.text.trim();
    final opts = _options
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (q.isEmpty) {
      setState(() => _error = 'اكتبي سؤال الاستطلاع');
      return;
    }
    if (opts.length < _minOptions) {
      setState(() => _error = 'اكتبي خيارين على الأقل');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AdminApi.instance.add('poll', {'question': q, 'options': opts});
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('استطلاع جديد',
          style: TextStyle(fontWeight: FontWeight.w800, color: C.poll)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _question,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'السؤال'),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < _options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _options[i],
                          enabled: !_busy,
                          style: const TextStyle(fontSize: 17),
                          decoration: InputDecoration(
                              labelText: 'الخيار ${i + 1}'),
                        ),
                      ),
                      if (_options.length > _minOptions)
                        IconButton(
                          tooltip: 'حذف الخيار',
                          onPressed: _busy ? null : () => _removeOption(i),
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: C.error),
                        ),
                    ],
                  ),
                ),
              if (_options.length < _maxOptions)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _addOption,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('إضافة خيار'),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: C.error, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.poll),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Colors.white))
              : const Text('نشر الاستطلاع'),
        ),
      ],
    );
  }
}
