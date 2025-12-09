// lib/main.dart
import 'package:fast_flow/models/user_model.dart';
import 'package:fast_flow/pages/fasting_history_page.dart';
import 'package:fast_flow/pages/fasting_review_history_page.dart';
import 'package:fast_flow/pages/login_page.dart';
import 'package:fast_flow/pages/main_page.dart';
import 'package:fast_flow/pages/kesan_pesan_page.dart';
import 'package:fast_flow/pages/splash_screen.dart';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Timezone
// import 'package:timezone/data/latest_all.dart' as tzdata;
// import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive init
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(UserModelAdapter());
  }

  await Hive.openBox('session');
  await Hive.openBox('auth');
  await Hive.openBox<UserModel>('users');
  await Hive.openBox('fastingBox');
  await Hive.openBox('fastingNotes');
  await Hive.openBox('infaqBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fasting Tracker',
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      // Start with splash screen. Splash decides where to go next.
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const MainPage(),
        '/kesan-pesan': (context) => const KesanPesanPage(),
        '/review-history': (context) => const FastingReviewHistoryPage(),
        '/fasting-history': (context) => const FastingHistoryPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
