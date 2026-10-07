import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class DashboardPage extends StatefulWidget {
  final void Function(int index) onNavigate;

  const DashboardPage({super.key, required this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Stats? _stats;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final st = await AdminApi.instance.stats();
      if (!mounted) return;
      setState(() {
        _stats = st;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errText(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final st = _stats!;

    final cards = <Widget>[
      _StatCard(
        title: 'منشورات جديدنا',
        value: st.count('product'),
        icon: Icons.local_offer_rounded,
        color: C.products,
        bg: C.productsBg,
        onTap: () => widget.onNavigate(1),
      ),
      _StatCard(
        title: 'معلومات هل تعلم',
        value: st.count('info'),
        icon: Icons.lightbulb_rounded,
        color: C.info,
        bg: C.infoBg,
        onTap: () => widget.onNavigate(2),
      ),
      _StatCard(
        title: 'أفكار المستخدمين',
        value: st.count('share'),
        note: st.unreadShares > 0 ? '${st.unreadShares} جديدة' : null,
        icon: Icons.edit_note_rounded,
        color: C.ideas,
        bg: C.ideasBg,
        onTap: () => widget.onNavigate(3),
      ),
      _StatCard(
        title: 'القصص',
        value: st.count('story'),
        note: st.count('story_continue') > 0
            ? '${st.count('story_continue')} تكملة'
            : null,
        icon: Icons.menu_book_rounded,
        color: C.story,
        bg: C.storyBg,
        onTap: () => widget.onNavigate(4),
      ),
      _StatCard(
        title: 'الاستطلاعات',
        value: st.count('poll'),
        icon: Icons.how_to_vote_rounded,
        color: C.poll,
        bg: C.pollBg,
        onTap: () => widget.onNavigate(5),
      ),
    ];

    return RefreshIndicator(
      color: C.primary,
      onRefresh: _load,
      child: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('أهلاً بكِ 👋',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: C.primary)),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Text('هذا ملخص تطبيق «اكسب وقتك». اضغطي على أي بطاقة للإدارة.',
                      style: TextStyle(fontSize: 16, color: C.textSoft)),
                ),
                Wrap(spacing: 14, runSpacing: 14, children: cards),
                const SizedBox(height: 22),
                AdminCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline_rounded, color: C.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'أي منشور تضيفينه أو تحذفينه يظهر في التطبيق فوراً '
                          'عند فتح الصفحة أو سحبها للتحديث.',
                          style: TextStyle(fontSize: 16, height: 1.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final String? note;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AdminCard(
            borderColor: color.withValues(alpha: 0.4),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$value',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: color,
                              height: 1.1)),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      if (note != null)
                        Text(note!,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: color)),
                    ],
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
