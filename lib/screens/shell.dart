import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'dashboard_page.dart';
import 'info_page.dart';
import 'polls_page.dart';
import 'products_page.dart';
import 'shares_page.dart';
import 'stories_page.dart';

class _Section {
  final String title;
  final IconData icon;
  final Color color;

  const _Section(this.title, this.icon, this.color);
}

const List<_Section> _sections = [
  _Section('الرئيسية', Icons.dashboard_rounded, C.primary),
  _Section('جديدنا (المنتجات)', Icons.local_offer_rounded, C.products),
  _Section('هل تعلم', Icons.lightbulb_rounded, C.info),
  _Section('أفكار المستخدمين', Icons.edit_note_rounded, C.ideas),
  _Section('القصص', Icons.menu_book_rounded, C.story),
  _Section('الاستطلاعات', Icons.how_to_vote_rounded, C.poll),
];

const int kIdeasIndex = 3;

class AdminShell extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminShell({super.key, required this.onLogout});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  Widget _page() {
    switch (_index) {
      case 0:
        return DashboardPage(key: const ValueKey('p0'), onNavigate: _go);
      case 1:
        return const ProductsPage(key: ValueKey('p1'));
      case 2:
        return const InfoPage(key: ValueKey('p2'));
      case 3:
        return const SharesPage(key: ValueKey('p3'));
      case 4:
        return const StoriesPage(key: ValueKey('p4'));
      default:
        return const PollsPage(key: ValueKey('p5'));
    }
  }

  Future<void> _logoutConfirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريدين تسجيل الخروج من لوحة التحكم؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('خروج')),
        ],
      ),
    );
    if (ok == true) widget.onLogout();
  }

  Widget _sidebar({required bool inDrawer}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.splashTop, C.splashMid, C.primary],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Image.asset('assets/images/logo_emblem.png', width: 92),
            const SizedBox(height: 8),
            Image.asset('assets/images/logo_text_cream.png', width: 130),
            const SizedBox(height: 4),
            const Text('لوحة التحكم',
                style: TextStyle(color: C.cream, fontSize: 15)),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < _sections.length; i++)
                    _NavItem(
                      section: _sections[i],
                      selected: _index == i,
                      showBadge: i == kIdeasIndex,
                      onTap: () {
                        if (inDrawer) Navigator.of(context).pop();
                        _go(i);
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: TextButton.icon(
                onPressed: _logoutConfirm,
                style: TextButton.styleFrom(
                  foregroundColor: C.cream,
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(width: 270, child: _sidebar(inDrawer: false)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: _page(),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_sections[_index].title)),
      drawer: Drawer(child: _sidebar(inDrawer: true)),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _page(),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _Section section;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavItem({
    required this.section,
    required this.selected,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? C.cream : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(section.icon,
                    size: 26, color: selected ? section.color : C.cream),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: selected ? C.text : C.cream,
                    ),
                  ),
                ),
                if (showBadge)
                  ValueListenableBuilder<int>(
                    valueListenable: AdminState.unread,
                    builder: (_, n, _) => n <= 0
                        ? const SizedBox.shrink()
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: C.gold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('$n',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: C.text)),
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
