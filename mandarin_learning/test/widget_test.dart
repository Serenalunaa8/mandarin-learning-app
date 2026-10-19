import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mandarin_learning/providers/auth_provider.dart';
import 'package:mandarin_learning/providers/vocabulary_provider.dart';
import 'package:mandarin_learning/screens/auth/welcome_screen.dart';

void main() {
  testWidgets('WelcomeScreen renders title and buttons properly', (WidgetTester tester) async {
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

    // Verifikasi teks judul
    expect(find.text('Learn Languages.\nLevel Up Your World.'), findsOneWidget);
    // Verifikasi tombol
    expect(find.text('Mulai Belajar'), findsOneWidget);
    expect(find.text('Eksplorasi Mode Tamu (Tanpa Akun)'), findsOneWidget);
  });
}
