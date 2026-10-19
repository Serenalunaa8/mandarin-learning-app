import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import 'vocabulary_detail_screen.dart';

class LessonPathScreen extends StatelessWidget {
  const LessonPathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vocab = context.watch<VocabularyProvider>();
    final currentLevel = vocab.selectedLevel;
    final units = vocab.currentLevelUnits;
    final totalWords = vocab.currentLevelVocabulary.length;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Learning Path'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '${auth.coins}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.coinGold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Pilihan Level HSK (1 s.d. 6)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.forestGreen,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.forestGreen.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown Level
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: currentLevel,
                        dropdownColor: AppColors.forestGreen,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        items: List.generate(6, (index) {
                          final lvl = index + 1;
                          final count = lvl == 1 ? 150 : (lvl == 2 ? 150 : (lvl == 3 ? 300 : (lvl == 4 ? 600 : (lvl == 5 ? 1300 : 2500))));
                          return DropdownMenuItem<int>(
                            value: lvl,
                            child: Text(
                              'HSK $lvl • $count Kata',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }),
                        onChanged: (newLevel) {
                          if (newLevel != null) {
                            vocab.setLevel(newLevel);
                            auth.setHskLevel(newLevel);
                          }
                        },
                      ),
                    ),
                    Text(
                      'Unit ${vocab.selectedUnit} • ${(totalWords / 10).ceil()} Total Unit',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),

          // Stepping Stones Node Path
          Expanded(
            child: vocab.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : units.isEmpty
                    ? Center(
                        child: Text(
                          'Kosakata untuk HSK $currentLevel sedang dimuat...',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                        itemCount: units.length,
                        itemBuilder: (context, index) {
                          final unitNum = index + 1;
                          final unitWords = units[unitNum] ?? [];
                          final isCurrent = unitNum == vocab.selectedUnit;
                          final isCompleted = unitWords.isNotEmpty &&
                              unitWords.every((w) => vocab.isLearned(w.id));
                          final isLocked = unitNum > vocab.selectedUnit + 1;

                          // Alternating alignment: center-left, center, center-right
                          Alignment alignment;
                          if (index % 4 == 0) {
                            alignment = Alignment.center;
                          } else if (index % 4 == 1) {
                            alignment = const Alignment(0.4, 0);
                          } else if (index % 4 == 2) {
                            alignment = Alignment.center;
                          } else {
                            alignment = const Alignment(-0.4, 0);
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Align(
                              alignment: alignment,
                              child: Column(
                                children: [
                                  if (isCurrent)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'START 🟢',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () {
                                      vocab.setUnit(unitNum);
                                      _showUnitVocabModal(context, unitNum, unitWords);
                                    },
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isCompleted
                                            ? const Color(0xFF16A34A)
                                            : isCurrent
                                                ? AppColors.primary
                                                : isLocked
                                                    ? AppColors.nodeLocked
                                                    : const Color(0xFF86EFAC),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isCompleted || isCurrent)
                                                ? AppColors.primary.withValues(alpha: 0.4)
                                                : Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 4,
                                        ),
                                      ),
                                      child: Center(
                                        child: isCompleted
                                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 36)
                                            : isLocked
                                                ? const Icon(Icons.lock_rounded, color: Colors.white70, size: 28)
                                                : isCurrent
                                                    ? const Icon(Icons.headphones_rounded, color: Colors.white, size: 32)
                                                    : Text(
                                                        '$unitNum',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 22,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Unit $unitNum',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isCurrent ? AppColors.primaryDark : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showUnitVocabModal(BuildContext context, int unitNum, List<VocabularyItem> words) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Unit $unitNum (${words.length} Kata)',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                'Pilih kosakata untuk melihat detail, pelafalan audio, dan contoh',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: words.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, idx) {
                    final item = words[idx];
                    final isLearned = context.watch<VocabularyProvider>().isLearned(item.id);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      leading: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isLearned ? AppColors.primaryLight : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            item.hanzi,
                            style: TextStyle(
                              fontSize: item.hanzi.length > 2 ? 16 : 20,
                              fontWeight: FontWeight.bold,
                              color: isLearned ? AppColors.primaryDark : AppColors.textDark,
                            ),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            item.pinyin,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          if (isLearned) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        item.artiIndonesia,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VocabularyDetailScreen(item: item),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
