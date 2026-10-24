import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';

void showDailyGoalBottomSheet(BuildContext context, AuthProvider auth) {
  int selectedMinutes = auth.dailyGoalMinutes;
  final presets = [
    {'minutes': 15, 'title': '15 Menit', 'desc': 'Santai'},
    {'minutes': 30, 'title': '30 Menit', 'desc': 'Standar'},
    {'minutes': 60, 'title': '60 Menit', 'desc': 'Fokus'},
  ];

  bool isCustom = selectedMinutes != 15 && selectedMinutes != 30 && selectedMinutes != 60;
  final customController = TextEditingController(
    text: isCustom ? selectedMinutes.toString() : '',
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: Color(0xFF16A34A),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Target Belajar Harian',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A24),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pilih rekomendasi durasi atau ketik kustom',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 3 Preset Options Row
                    Row(
                      children: presets.map((item) {
                        final minutes = item['minutes'] as int;
                        final isSelected = !isCustom && selectedMinutes == minutes;

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                isCustom = false;
                                selectedMinutes = minutes;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF1E3A24),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item['desc'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Custom Option Card
                    GestureDetector(
                      onTap: () {
                        setModalState(() {
                          isCustom = true;
                          if (customController.text.isEmpty) {
                            customController.text = selectedMinutes.toString();
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCustom ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCustom ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                            width: isCustom ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 20,
                                  color: isCustom ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Kustom (Ketik durasi menit sendiri)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isCustom ? const Color(0xFF16A34A) : const Color(0xFF1E3A24),
                                  ),
                                ),
                              ],
                            ),
                            if (isCustom) ...[
                              const SizedBox(height: 10),
                              TextField(
                                controller: customController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: 'Contoh: 190',
                                  suffixText: 'menit',
                                  suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.8),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Target Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          int finalTarget = selectedMinutes;
                          if (isCustom) {
                            final input = int.tryParse(customController.text.trim());
                            if (input == null || input <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Masukkan durasi menit yang valid (minimal 1 menit).'),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            finalTarget = input;
                          }

                          Navigator.pop(ctx);
                          await auth.updateDailyGoalMinutes(finalTarget);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Target harian berhasil disimpan: $finalTarget menit'),
                                backgroundColor: const Color(0xFF16A34A),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Simpan Target',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
