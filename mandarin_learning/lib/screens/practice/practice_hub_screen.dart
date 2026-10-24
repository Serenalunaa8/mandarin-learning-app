import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../auth/register_screen.dart';
import 'ai_tutor_screen.dart';

class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});

  void _openAiTutor(BuildContext context, {required bool isGuest}) {
    if (isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'AI Tutor hanya tersedia untuk akun terdaftar. Silakan daftar untuk mengakses.',
          ),
          action: SnackBarAction(
            label: 'Daftar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiTutorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = context.watch<AuthProvider>().isGuest;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('Praktik Mandarin')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _openAiTutor(context, isGuest: isGuest),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text('🤖', style: TextStyle(fontSize: 30)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Tutor Mandarin',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Tanyakan tata bahasa, contoh percakapan, dan tips pelafalan kapan saja.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primaryDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
