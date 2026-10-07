import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';
import 'product_form.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final AdminApi _api = AdminApi.instance;
  final List<Map<String, dynamic>> _items = [];

  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

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
      final r = await _api.list('product', page: 1, limit: 10);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(rowsOf(r));
        _page = 1;
        _hasMore = r['hasMore'] == true;
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

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final r = await _api.list('product', page: _page + 1, limit: 10);
      if (!mounted) return;
      final ids = _items.map((e) => s(e, 'id')).toSet();
      final fresh = rowsOf(r).where((e) => !ids.contains(s(e, 'id'))).toList();
      setState(() {
        _items.addAll(fresh);
        _page++;
        _hasMore = r['hasMore'] == true;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showMsg(context, errText(e), error: true);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? product]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProductFormPage(product: product),
      ),
    );
    if (saved == true) {
      if (!mounted) return;
      showMsg(context, product == null ? 'تمت إضافة المنتج ✓' : 'تم حفظ التعديل ✓');
      _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف المنتج',
      message: 'سيتم حذف «${s(p, 'name')}» وصوره نهائياً ولن يظهر في التطبيق. هل أنتِ متأكدة؟',
    );
    if (!ok) return;
    try {
      await _api.delete('product', s(p, 'id'));
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => s(e, 'id') == s(p, 'id')));
      showMsg(context, 'تم حذف المنتج');
    } catch (e) {
      if (!mounted) return;
      showMsg(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = SectionHeader(
      title: 'جديدنا',
      subtitle: 'المنتجات والعروض التي تظهر في التطبيق',
      icon: Icons.local_offer_rounded,
      color: C.products,
      bgColor: C.productsBg,
      action: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: C.products),
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('منتج جديد'),
      ),
    );

    if (_loading) {
      return PageBody(child: Column(children: [header, const Expanded(child: LoadingView())]));
    }
    if (_error != null) {
      return PageBody(
        child: Column(children: [
          header,
          Expanded(child: ErrorView(message: _error!, onRetry: _load)),
        ]),
      );
    }

    return PageBody(
      child: RefreshIndicator(
        color: C.primary,
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _items.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) return header;
            if (_items.isEmpty) {
              return const EmptyView(
                icon: Icons.local_offer_rounded,
                text: 'لا يوجد منتجات بعد.\nاضغطي «منتج جديد» لإضافة أول منشور.',
                color: C.products,
              );
            }
            if (i == _items.length + 1) {
              if (!_hasMore) return const SizedBox(height: 24);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: _loadingMore
                      ? const CircularProgressIndicator(color: C.products)
                      : OutlinedButton.icon(
                          onPressed: _loadMore,
                          icon: const Icon(Icons.expand_more_rounded),
                          label: const Text('تحميل المزيد'),
                        ),
                ),
              );
            }
            final p = _items[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProductTile(
                product: p,
                onEdit: () => _openForm(p),
                onDelete: () => _delete(p),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final images = (product['images'] as List?) ?? const [];
    final price = s(product, 'price');
    final note = s(product, 'price_note');

    final thumbBox = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 96,
        height: 96,
        child: images.isEmpty
            ? Container(
                color: C.productsBg,
                child: const Icon(Icons.image_outlined, color: C.products, size: 36),
              )
            : Image.network(
                thumb(images.first.toString()),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: C.productsBg,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: C.products),
                ),
              ),
      ),
    );

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              thumbBox,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s(product, 'name'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (price.isNotEmpty)
                          _Chip(
                              text: '$price\$${note.isEmpty ? '' : ' $note'}',
                              color: C.products,
                              bg: C.productsBg),
                        _Chip(
                            text: '${images.length} صور',
                            color: C.textSoft,
                            bg: C.bg),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(s(product, 'body'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, color: C.textSoft, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(fmtDate(s(product, 'created_at')),
              style: const TextStyle(fontSize: 13, color: C.textSoft)),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('تعديل'),
              ),
              const SizedBox(width: 10),
              DeleteButton(onPressed: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;

  const _Chip({required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            textDirection: TextDirection.ltr,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      );
}
