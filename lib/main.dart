import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'config.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';

const String kSavedPasswordKey = 'yahala_admin_pw';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'لوحة تحكم اكسب وقتك',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Gate(),
    );
  }
}

enum _AuthState { checking, loggedOut, loggedIn }

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  _AuthState _state = _AuthState.checking;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (!AdminConfig.isConfigured) {
      setState(() => _state = _AuthState.loggedOut);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kSavedPasswordKey);
      if (saved != null && saved.isNotEmpty) {
        AdminApi.instance.setPassword(saved);
        await AdminApi.instance.ping();
        if (!mounted) return;
        setState(() => _state = _AuthState.loggedIn);
        return;
      }
    } catch (_) {
      AdminApi.instance.clear();
    }
    if (!mounted) return;
    setState(() => _state = _AuthState.loggedOut);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kSavedPasswordKey);
    AdminApi.instance.clear();
    if (!mounted) return;
    setState(() => _state = _AuthState.loggedOut);
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _AuthState.checking:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: C.primary)),
        );
      case _AuthState.loggedOut:
        return LoginScreen(
          onLoggedIn: () => setState(() => _state = _AuthState.loggedIn),
        );
      case _AuthState.loggedIn:
        return AdminShell(onLogout: _logout);
    }
  }
}
