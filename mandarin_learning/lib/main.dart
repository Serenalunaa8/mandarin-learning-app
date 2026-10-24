import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/vocabulary_provider.dart';
import 'services/supabase_service.dart';
import 'services/audio_service.dart';
import 'services/notification_service.dart';
import 'screens/auth/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase
  try {
    await SupabaseService.instance.initialize();
  } catch (e) {
    debugPrint('[Main] Supabase init warning: $e');
  }

  // Inisialisasi Audio TTS
  try {
    await AudioService.instance.initialize();
  } catch (e) {
    debugPrint('[Main] Audio init warning: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VocabularyProvider()),
      ],
      child: const MandarinLearningApp(),
    ),
  );
}

class MandarinLearningApp extends StatefulWidget {
  const MandarinLearningApp({super.key});

  @override
  State<MandarinLearningApp> createState() => _MandarinLearningAppState();
}

class _MandarinLearningAppState extends State<MandarinLearningApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.checkSession();
      if (mounted) {
        final vocab = context.read<VocabularyProvider>();
        await vocab.initialize(auth.profile?.id);
      }
      try {
        await NotificationService.instance.restoreDailyReminder();
      } catch (e) {
        debugPrint('[Main] Gagal memulihkan pengingat harian: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Mandarin Learning HSK 1-6',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: auth.isLoading
          ? Scaffold(
              backgroundColor: const Color(0xFFF1F8F4),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/image/beranda/maskot_01_bintang.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: Color(0xFF22C55E)),
                  ],
                ),
              ),
            )
          : const LandingScreen(),
    );
  }
}
