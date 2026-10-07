import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class _Img {
  String? url;
  final Uint8List? bytes;

  _Img({this.url, this.bytes});
}

class ProductFormPage extends StatefulWidget {
  final Map<String, dynamic>? product;

  const ProductFormPage({super.key, this.product});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  static const int _maxImages = 5;
  static const List<String> _noteSuggestions = [
    'أسبوعياً',
    'شهرياً',
    'كاش',
    'بالتقسيط',
  ];

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _wa = TextEditingController();
  final List<_Img> _imgs = [];

  bool _saving = false;
  String _progress = '';
  String? _error;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _name.text = s(p, 'name');
      _price.text = s(p, 'price');
      _note.text = s(p, 'price_note');
      _body.text = s(p, 'body');
      _wa.text = s(p, 'wa_number');
      for (final u in (p['images'] as List?) ?? const []) {
        _imgs.add(_Img(url: u.toString()));
      }
    }
    _price.addListener(() => setState(() {}));
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _note.dispose();
    _body.dispose();
    _wa.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final room = _maxImages - _imgs.length;
    if (room <= 0) {
      showMsg(context, 'الحد الأقصى $_maxImages صور لكل منتج', error: true);
      return;
    }
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (files.isEmpty) return;
      final added = <_Img>[];
      for (final f in files.take(room)) {
        added.add(_Img(bytes: await f.readAsBytes()));
      }
      if (!mounted) return;
      setState(() => _imgs.addAll(added));
      if (files.length > room) {
        showMsg(context, 'تمت إضافة $room فقط (الحد الأقصى $_maxImages صور)');
      }
    } catch (_) {
      if (!mounted) return;
      showMsg(context, 'تعذّر فتح معرض الصور', error: true);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتبي اسم المنتج أو عنوان المنشور');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // 1) رفع الصور الجديدة بالترتيب (مرة واحدة حتى لو أعدنا المحاولة)
      final pending = _imgs.where((e) => e.url == null).length;
      var done = 0;
      for (final img in _imgs) {
        if (img.url != null) continue;
        done++;
        if (mounted) setState(() => _progress = 'جاري رفع الصورة $done من $pending...');
        img.url = await AdminApi.instance.uploadImage(img.bytes!);
      }

      // 2) حفظ المنتج
      if (mounted) setState(() => _progress = 'جاري الحفظ...');
      final data = <String, dynamic>{
        'name': name,
        'price': _price.text.trim(),
        'price_note': _note.text.trim(),
        'body': _body.text.trim(),
        'wa_number': _wa.text.trim(),
        'images': _imgs.map((e) => e.url).whereType<String>().toList(),
      };
      if (_isEdit) {
        await AdminApi.instance.update('product', s(widget.product!, 'id'), data);
      } else {
        await AdminApi.instance.add('product', data);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _progress = '';
        _error = errText(e);
      });
    }
  }

  Future<bool> _confirmLeave() async {
    if (_saving) return false;
    return confirmDialog(
      context,
      title: 'إغلاق النموذج',
      message: 'لن يتم حفظ ما كتبتِ. هل تريدين الإغلاق؟',
      okLabel: 'إغلاق',
    );
  }

  Widget _imageTile(int i) {
    final img = _imgs[i];
    final Widget picture = img.bytes != null
        ? Image.memory(img.bytes!, fit: BoxFit.cover)
        : Image.network(
            thumb(img.url!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: C.productsBg,
              child: const Icon(Icons.image_not_supported_outlined,
                  color: C.products),
            ),
          );

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: picture),
          if (i == 0)
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: C.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('الغلاف',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          Positioned(
            top: 4,
            left: 4,
            child: InkWell(
              onTap: _saving ? null : () => setState(() => _imgs.removeAt(i)),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: C.error, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = _price.text.trim();
    final note = _note.text.trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: C.products,
          title: Text(_isEdit ? 'تعديل المنتج' : 'منتج جديد'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final leave = await _confirmLeave();
              if (leave && context.mounted) Navigator.of(context).pop(false);
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PageBody(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── الصور ───
                  AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الصور (${_imgs.length}/$_maxImages)',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text(
                            'الصورة الأولى هي الغلاف. يمكنك اختيار عدة صور دفعة واحدة من المعرض.',
                            style: TextStyle(color: C.textSoft, fontSize: 14)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (var i = 0; i < _imgs.length; i++) _imageTile(i),
                            if (_imgs.length < _maxImages)
                              InkWell(
                                onTap: _saving ? null : _pickImages,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: C.productsBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: C.products.withValues(alpha: 0.5),
                                        width: 1.6),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined,
                                          size: 36, color: C.products),
                                      SizedBox(height: 6),
                                      Text('إضافة صور',
                                          style: TextStyle(
                                              color: C.products,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ─── النصوص ───
                  AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _name,
                          enabled: !_saving,
                          maxLength: 200,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                              labelText: 'اسم المنتج / عنوان المنشور *'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _price,
                                enabled: !_saving,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                style: const TextStyle(fontSize: 18),
                                decoration: const InputDecoration(
                                  labelText: 'السعر بالدولار (رقم فقط)',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _note,
                                enabled: !_saving,
                                maxLength: 50,
                                style: const TextStyle(fontSize: 18),
                                decoration: const InputDecoration(
                                  labelText: 'ملاحظة السعر (اختياري)',
                                  hintText: 'أسبوعياً',
                                ),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final n in _noteSuggestions)
                              ActionChip(
                                label: Text(n),
                                onPressed: _saving ? null : () => _note.text = n,
                              ),
                          ],
                        ),
                        if (price.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: C.productsBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'يظهر في التطبيق: $price\$${note.isEmpty ? '' : ' $note'}',
                                style: const TextStyle(
                                    color: C.products,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _body,
                          enabled: !_saving,
                          minLines: 8,
                          maxLines: 20,
                          style: const TextStyle(fontSize: 17, height: 1.6),
                          decoration: const InputDecoration(
                            labelText: 'نص المنشور (الوصف والمواصفات)',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _wa,
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            labelText: 'رقم واتساب لهذا المنتج (اختياري)',
                            hintText: '0941438579',
                            helperText:
                                'اتركيه فارغاً لاستخدام الرقم العام للتطبيق',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: C.error,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  if (_saving && _progress.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_progress,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16, color: C.textSoft)),
                    ),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.products),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_isEdit ? 'حفظ التعديل' : 'نشر المنتج'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
