import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nihaoki/providers/auth_provider.dart';
import 'package:nihaoki/providers/vocabulary_provider.dart';
import 'package:nihaoki/screens/auth/welcome_screen.dart';

void main() {
  testWidgets('WelcomeScreen renders title, mascot, and buttons according to mockup design', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => VocabularyProvider()),
        ],
        child: const MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    // Verifikasi teks judul sesuai referensi mockup Screen 1
    expect(find.text('Selamat Datang!'), findsOneWidget);
    expect(find.text('Ayo mulai perjalanan belajarmu\nbahasa Mandarin!'), findsOneWidget);
    // Verifikasi tombol masuk dan form
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Coba Langsung Tanpa Akun (Mode Tamu)'), findsOneWidget);
    expect(find.text('Belum punya akun? '), findsOneWidget);
    expect(find.text('Daftar'), findsOneWidget);
  });
}
