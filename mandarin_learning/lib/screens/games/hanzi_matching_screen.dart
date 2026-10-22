import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/mascot_widget.dart';

// FR-07: Hanzi Matching — 8 kartu (4 Bahasa Mandarin & 4 Bahasa Indonesia) dengan posisi acak
// Cocokkan kartu Hanzi dengan kartu Arti Indonesia
// FR-18: Bonus 25 koin tiap 5 kemenangan beruntun (idempotent per streak milestone)
// FR-19: Bantuan 30 koin — mencocokkan otomatis 1 pasang kartu

class HanziMatchingScreen extends StatefulWidget {
  const HanziMatchingScreen({super.key});

  @override
  State<HanziMatchingScreen> createState() => _HanziMatchingScreenState();
}

class _HanziMatchingScreenState extends State<HanziMatchingScreen>
    with TickerProviderStateMixin {
  static const int _pairCount = 4; // 4 pasang = 8 kartu total

  List<_CardData> _cards = [];
  int? _selectedCardIndex;
  bool _isChecking = false;

  int _consecutiveWins = 0; // streak
  final Set<int> _awardedStreakMilestones = {}; // FR-18 idempotent
  bool _roundComplete = false;
  bool _usedHintThisRound = false;

  late AnimationController _successController;
  late Animation<double> _successScale;

  List<VocabularyItem> _pool = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _successScale = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndDeal());
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  Future<void> _loadAndDeal() async {
    final vocab = context.read<VocabularyProvider>();
    final words = vocab.currentLevelVocabulary;
    if (words.length < _pairCount) {
      setState(() => _isLoading = false);
      return;
    }
    _pool = words;
    _dealNewRound();
    setState(() => _isLoading = false);
  }

  void _dealNewRound() {
    final rng = Random();
    final shuffled = List<VocabularyItem>.from(_pool)..shuffle(rng);
    final chosenWords = shuffled.take(_pairCount).toList();

    // 4 Kartu Mandarin
    final mandarinList = chosenWords.map((item) {
      return _CardData(
        vocabId: item.id,
        mainText: item.hanzi,
        subText: item.pinyin,
        isMandarin: true,
        isMatched: false,
      );
    }).toList();

    // 4 Kartu Bahasa Indonesia
    final indoList = chosenWords.map((item) {
      return _CardData(
        vocabId: item.id,
        mainText: item.artiIndonesia,
        subText: 'Indonesia',
        isMandarin: false,
        isMatched: false,
      );
    }).toList();

    // Posisi 8 kartu diacak sepenuhnya (tidak dipisah kiri-kanan)
    final allCards = [...mandarinList, ...indoList]..shuffle(rng);

    setState(() {
      _cards = allCards;
      _selectedCardIndex = null;
      _isChecking = false;
      _roundComplete = false;
      _usedHintThisRound = false;
    });
  }

  void _onTapCard(int index) {
    if (_isChecking || _roundComplete) return;
    if (_cards[index].isMatched) return;

    if (_selectedCardIndex == null) {
      setState(() => _selectedCardIndex = index);
      return;
    }

    if (_selectedCardIndex == index) {
      // Klik kartu yang sama -> batalkan pilihan
      setState(() => _selectedCardIndex = null);
      return;
    }

    final firstIndex = _selectedCardIndex!;
    final firstCard = _cards[firstIndex];
    final secondCard = _cards[index];

    // Jika kedua kartu sama bahasa (Mandarin & Mandarin atau Indo & Indo), pindahkan seleksi
    if (firstCard.isMandarin == secondCard.isMandarin) {
      setState(() => _selectedCardIndex = index);
      return;
    }

    _isChecking = true;

    if (firstCard.vocabId == secondCard.vocabId) {
      // ✅ Cocok!
      setState(() {
        _cards[firstIndex] = firstCard.copyWith(isMatched: true);
        _cards[index] = secondCard.copyWith(isMatched: true);
        _selectedCardIndex = null;
        _isChecking = false;
      });

      // Cek apakah semua 8 kartu telah cocok
      if (_cards.every((c) => c.isMatched)) {
        if (!_usedHintThisRound) {
          _consecutiveWins++;
        }
        _onRoundComplete();
      }
    } else {
      // ❌ Salah, beri efek merah sesaat lalu batalkan seleksi
      setState(() {
        _cards[firstIndex] = firstCard.copyWith(isError: true);
        _cards[index] = secondCard.copyWith(isError: true);
      });

      Future.delayed(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        setState(() {
          _cards[firstIndex] = _cards[firstIndex].copyWith(isError: false);
          _cards[index] = _cards[index].copyWith(isError: false);
          _selectedCardIndex = null;
          _isChecking = false;
        });
      });
    }
  }

  Future<void> _onRoundComplete() async {
    setState(() => _roundComplete = true);
    _successController.forward(from: 0);

    // FR-18: bonus 25 koin tiap 5 beruntun (idempotent)
    final milestone = (_consecutiveWins ~/ 5) * 5;
    if (milestone > 0 && !_awardedStreakMilestones.contains(milestone)) {
      _awardedStreakMilestones.add(milestone);
      await _addCoins(25, 'hanzi_matching_streak_$milestone');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🔥 Streak $_consecutiveWins! Bonus 25 koin streak berhasil diraih!',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    }
  }

  Future<void> _addCoins(int amount, String attemptId) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.addCoins(
      amount,
      'hanzi_matching',
      'Streak bonus Hanzi Matching ke-$_consecutiveWins',
      attemptId: attemptId,
    );
  }

  // FR-19: Bantuan — deduct 30 koin, cocokkan otomatis 1 pasang kartu yang tersisa
  Future<void> _useHint() async {
    if (_roundComplete) return;

    final auth = context.read<AuthProvider>();
    final balance = auth.coins;
    if (balance < 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koin tidak cukup! Butuh 30 💎 untuk bantuan.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Cari pasangan pertama yang belum cocok
    int? mIndex;
    int? iIndex;

    for (var m = 0; m < _cards.length; m++) {
      if (!_cards[m].isMatched && _cards[m].isMandarin) {
        mIndex = m;
        final targetVocabId = _cards[m].vocabId;
        for (var i = 0; i < _cards.length; i++) {
          if (!_cards[i].isMatched && !_cards[i].isMandarin && _cards[i].vocabId == targetVocabId) {
            iIndex = i;
            break;
          }
        }
        break;
      }
    }

    if (mIndex == null || iIndex == null) return;

    final success = await auth.deductCoins(
      30,
      'bantuan_hanzi_matching',
      'Bantuan eliminasi pasangan Hanzi Matching',
      attemptId: 'hint_hanzi_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (!success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menukarkan bantuan.')),
      );
      return;
    }

    _usedHintThisRound = true;

    setState(() {
      _cards[mIndex!] = _cards[mIndex].copyWith(isMatched: true);
      _cards[iIndex!] = _cards[iIndex].copyWith(isMatched: true);
      _selectedCardIndex = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💡 Bantuan digunakan (-30 💎)! 1 pasang dicocokkan.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
    }

    if (_cards.every((c) => c.isMatched)) {
      _onRoundComplete();
    }
  }

  void _nextRound() {
    _dealNewRound();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Hanzi Matching (8 Kartu)'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
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
                const Text('💎', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '${auth.coins}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pool.length < _pairCount
              ? _buildEmptyState()
              : SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shuffle_rounded, size: 16, color: AppColors.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Posisi 8 kartu diacak. Cocokkan 1 kartu Mandarin dengan 1 kartu artinya.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(child: _buildMatchingGrid()),
                      _buildBottomBar(),
                      if (_roundComplete) _buildRoundCompleteOverlay(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Streak Kemenangan',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < (_consecutiveWins % 5)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Streak Saat Ini',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                '$_consecutiveWins Beruntun',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const crossAxisCount = 2;
          const rows = 4;
          const spacing = 10.0;
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;
          final itemWidth = (availableWidth - spacing) / crossAxisCount;
          final itemHeight = (availableHeight - (rows - 1) * spacing) / rows;
          final ratio = (itemWidth / itemHeight).clamp(1.1, 2.6);

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cards.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: ratio,
            ),
            itemBuilder: (context, index) {
              final card = _cards[index];
              final isSelected = _selectedCardIndex == index;
              return _buildCardTile(
                card: card,
                isSelected: isSelected,
                onTap: () => _onTapCard(index),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCardTile({
    required _CardData card,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFE2E8F0);
    double borderWidth = 1.5;

    if (card.isMatched) {
      bgColor = const Color(0xFFD1FAE5);
      borderColor = AppColors.primaryGreen;
      borderWidth = 2.0;
    } else if (card.isError) {
      bgColor = const Color(0xFFFEE2E2);
      borderColor = Colors.red;
      borderWidth = 2.0;
    } else if (isSelected) {
      bgColor = card.isMandarin ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7);
      borderColor = card.isMandarin ? AppColors.primaryDark : const Color(0xFFD97706);
      borderWidth = 2.5;
    }

    return GestureDetector(
      onTap: card.isMatched ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.08 : 0.03),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (card.isMandarin) ...[
                      Text(
                        card.mainText,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: card.isMatched
                              ? AppColors.primaryGreen
                              : AppColors.primaryDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.subText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: card.isMatched
                              ? AppColors.primaryGreen
                              : AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      Text(
                        card.mainText,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: card.isMatched
                              ? AppColors.primaryGreen
                              : AppColors.textDark,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (card.isMatched)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryGreen,
                          size: 16,
                        ),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _roundComplete ? null : _useHint,
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
              label: const Text('Bantuan (-30 💎)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD97706),
                side: const BorderSide(color: Color(0xFFF59E0B)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _roundComplete ? _nextRound : null,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: const Text('Ronde Berikutnya'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundCompleteOverlay() {
    final isStreakMilestone =
        _consecutiveWins > 0 && _consecutiveWins % 5 == 0;

    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: ScaleTransition(
          scale: _successScale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MascotWidget(pose: MascotPose.celebrating, size: 90),
                const SizedBox(height: 12),
                const Text(
                  'Luar Biasa!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Semua 4 pasang kata berhasil dicocokkan dengan tepat!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                if (isStreakMilestone) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          'Streak Milestone $_consecutiveWins! +25 💎',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextRound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Lanjut Ronde Berikutnya',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MascotWidget(pose: MascotPose.holdingSign, size: 100),
          const SizedBox(height: 16),
          const Text(
            'Belum ada kosakata yang cukup di level ini.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
  }
}

class _CardData {
  final int vocabId;
  final String mainText;
  final String subText;
  final bool isMandarin;
  final bool isMatched;
  final bool isError;

  const _CardData({
    required this.vocabId,
    required this.mainText,
    required this.subText,
    required this.isMandarin,
    required this.isMatched,
    this.isError = false,
  });

  _CardData copyWith({
    bool? isMatched,
    bool? isError,
  }) {
    return _CardData(
      vocabId: vocabId,
      mainText: mainText,
      subText: subText,
      isMandarin: isMandarin,
      isMatched: isMatched ?? this.isMatched,
      isError: isError ?? this.isError,
    );
  }
}
