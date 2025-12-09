// lib/pages/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
// Timezone
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:fast_flow/utils/notification.dart';
import 'package:intl/date_symbol_data_local.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    // PENTING: panggil semua init di sini
    initializeApp().then((_) {
      _decideNext();
    });
  }

  Future<void> _decideNext() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    final session = Hive.box('session');

    /// Cocok dengan AuthService:
    /// is_logged_in = bool
    /// user_index = index user login
    final isLoggedIn = session.get('is_logged_in', defaultValue: false) == true;
    final userIndex = session.get('user_index');

    if (isLoggedIn && userIndex != null) {
      // Jika user login valid
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Belum login
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> initializeApp() async {
    // 1. Date formatting
    await initializeDateFormatting('id_ID', null);

    // 2. Timezone init
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (e) {
      debugPrint('Gagal set lokasi timezone: $e');
    }

    // 3. Notifications init
    await NotificationService().initNotification();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: Image.asset('assets/images/fastflow_logo.png',
                    fit: BoxFit.contain),
              ),
              const SizedBox(height: 20),
              Text(
                'Fast Flow',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Aplikasi tracker puasa islami',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
