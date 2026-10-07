import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../config.dart';
import '../main.dart' show kSavedPasswordKey;
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;

  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pw = TextEditingController();
  bool _hide = true;
  bool _remember = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final value = _pw.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'اكتب كلمة السر');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    AdminApi.instance.setPassword(value);
    try {
      await AdminApi.instance.ping();
      final prefs = await SharedPreferences.getInstance();
      if (_remember) {
        await prefs.setString(kSavedPasswordKey, value);
      } else {
        await prefs.remove(kSavedPasswordKey);
      }
      if (!mounted) return;
      widget.onLoggedIn();
    } catch (e) {
      AdminApi.instance.clear();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.splashTop, C.splashMid, C.primary],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo_emblem.png', width: 150),
                  const SizedBox(height: 12),
                  Image.asset('assets/images/logo_text_cream.png', width: 190),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'لوحة التحكم',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: C.primary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'سجّلي الدخول لإدارة التطبيق',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: C.textSoft),
                        ),
                        const SizedBox(height: 20),
                        if (!AdminConfig.isConfigured)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: C.ideasBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'تنبيه للمطوّر: لم يتم ضبط رابط Apps Script في lib/config.dart',
                              style: TextStyle(color: C.ideas, fontSize: 15),
                            ),
                          ),
                        TextField(
                          controller: _pw,
                          obscureText: _hide,
                          enabled: !_busy,
                          onSubmitted: (_) => _login(),
                          style: const TextStyle(fontSize: 18),
                          decoration: InputDecoration(
                            labelText: 'كلمة السر',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_hide
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _hide = !_hide),
                            ),
                          ),
                        ),
                        CheckboxListTile(
                          value: _remember,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _remember = v ?? true),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تذكّرني على هذا الجهاز',
                              style: TextStyle(fontSize: 16)),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: C.error,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: _busy ? null : _login,
                            child: _busy
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 3, color: Colors.white),
                                  )
                                : const Text('دخول'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
