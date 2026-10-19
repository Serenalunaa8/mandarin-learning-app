import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/vocabulary_provider.dart';
import 'services/supabase_service.dart';
import 'services/audio_service.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/home/main_navigation_screen.dart';

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
          ? const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🐼', style: TextStyle(fontSize: 60)),
                    SizedBox(height: 16),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            )
          : auth.isAuthenticated
              ? const MainNavigationScreen()
              : const WelcomeScreen(),
    );
  }
}
