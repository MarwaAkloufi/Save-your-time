import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class StoriesPage extends StatefulWidget {
  const StoriesPage({super.key});

  @override
  State<StoriesPage> createState() => _StoriesPageState();
}

class _StoriesPageState extends State<StoriesPage> {
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
      final rows = await _api.listAll('story');
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
      builder: (_) => const _NewStoryDialog(),
    );
    if (added == true) {
      if (!mounted) return;
      showMsg(context, 'تمت إضافة القصة ✓');
      _load(spinner: false);
    }
  }

  Future<void> _delete(Map<String, dynamic> it) async {
    final n = int.tryParse(s(it, 'continuations')) ?? 0;
    final ok = await confirmDialog(
      context,
      title: 'حذف القصة',
      message: n > 0
          ? 'سيتم حذف «${s(it, 'title')}» وكل تكملاتها ($n) نهائياً. هل أنتِ متأكدة؟'
          : 'سيتم حذف «${s(it, 'title')}» نهائياً. هل أنتِ متأكدة؟',
    );
    if (!ok) return;
    try {
      await _api.delete('story', s(it, 'id'));
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => s(e, 'id') == s(it, 'id')));
      showMsg(context, 'تم حذف القصة');
    } catch (e) {
      if (!mounted) return;
      showMsg(context, errText(e), error: true);
    }
  }

  Future<void> _openContinuations(Map<String, dynamic> it) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ContinuationsPage(story: it)),
    );
    if (mounted) _load(spinner: false); // لتحديث عدّاد التكملات
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: RefreshIndicator(
        color: C.story,
        onRefresh: () => _load(spinner: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              title: 'القصة لم تنتهِ بعد',
              subtitle: 'قصص مبتورة يكمّلها المستخدمون',
              icon: Icons.menu_book_rounded,
              color: C.story,
              bgColor: C.storyBg,
              action: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: C.story),
                onPressed: _openNew,
                icon: const Icon(Icons.add_rounded),
                label: const Text('قصة جديدة'),
              ),
            ),
            if (_loading)
              const LoadingView()
            else if (_error != null)
              ErrorView(message: _error!, onRetry: _load)
            else if (_items.isEmpty)
              const EmptyView(
                  icon: Icons.menu_book_outlined,
                  text: 'لا يوجد قصص بعد.\nاضغطي «قصة جديدة» لإضافة أول قصة.',
                  color: C.story)
            else
              for (final it in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(s(it, 'title'),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: C.story)),
                        const SizedBox(height: 6),
                        Text(s(it, 'content'),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, height: 1.7)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: C.story),
                              onPressed: () => _openContinuations(it),
                              icon: const Icon(Icons.forum_outlined, size: 20),
                              label: Text(
                                  'التكملات (${int.tryParse(s(it, 'continuations')) ?? 0})'),
                            ),
                            DeleteButton(onPressed: () => _delete(it)),
                            Text(fmtDate(s(it, 'created_at')),
                                style: const TextStyle(
                                    fontSize: 13, color: C.textSoft)),
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

// ─── حوار قصة جديدة ───
class _NewStoryDialog extends StatefulWidget {
  const _NewStoryDialog();

  @override
  State<_NewStoryDialog> createState() => _NewStoryDialogState();
}

class _NewStoryDialogState extends State<_NewStoryDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = _title.text.trim();
    final c = _content.text.trim();
    if (t.isEmpty || c.isEmpty) {
      setState(() => _error = 'اكتبي عنوان القصة وبدايتها');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AdminApi.instance.add('story', {'title': t, 'content': c});
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
      title: const Text('قصة جديدة',
          style: TextStyle(fontWeight: FontWeight.w800, color: C.story)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                enabled: !_busy,
                maxLength: 200,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'عنوان القصة'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _content,
                enabled: !_busy,
                minLines: 7,
                maxLines: 14,
                style: const TextStyle(fontSize: 17, height: 1.6),
                decoration: const InputDecoration(
                  labelText: 'بداية القصة (تنتهي بنقطة مفتوحة...)',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
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
          style: FilledButton.styleFrom(backgroundColor: C.story),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Colors.white))
              : const Text('نشر القصة'),
        ),
      ],
    );
  }
}

// ─── صفحة تكملات قصة واحدة ───
class _ContinuationsPage extends StatefulWidget {
  final Map<String, dynamic> story;

  const _ContinuationsPage({required this.story});

  @override
  State<_ContinuationsPage> createState() => _ContinuationsPageState();
}

class _ContinuationsPageState extends State<_ContinuationsPage> {
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
      final rows = await _api.listAll('story_continue',
          storyId: s(widget.story, 'id'));
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

  Future<void> _delete(Map<String, dynamic> it) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف التكملة',
      message: 'هل تريدين حذف هذه التكملة نهائياً؟',
    );
    if (!ok) return;
    try {
      await _api.delete('story_continue', s(it, 'id'));
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.story,
        title: Text(s(widget.story, 'title'),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: PageBody(
          child: RefreshIndicator(
            color: C.story,
            onRefresh: () => _load(spinner: false),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                AdminCard(
                  borderColor: C.story.withValues(alpha: 0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بداية القصة',
                          style: TextStyle(
                              color: C.story, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(s(widget.story, 'content'),
                          style: const TextStyle(fontSize: 16, height: 1.7)),
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
                      icon: Icons.forum_outlined,
                      text: 'لم يكتب أحد تكملة لهذه القصة بعد.',
                      color: C.story)
                else
                  for (final it in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AdminCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(fmtDate(s(it, 'created_at')),
                                style: const TextStyle(
                                    fontSize: 13, color: C.textSoft)),
                            const SizedBox(height: 6),
                            SelectableText(s(it, 'content'),
                                style: const TextStyle(fontSize: 17, height: 1.7)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: s(it, 'content')));
                                    if (!context.mounted) return;
                                    showMsg(context, 'تم النسخ');
                                  },
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
