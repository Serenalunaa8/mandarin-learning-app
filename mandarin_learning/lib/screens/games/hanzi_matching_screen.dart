import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/mascot_widget.dart';

// FR-07: Hanzi Matching — 8 kartu (4 Bahasa Mandarin & 4 Bahasa Indonesia)
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

  List<_CardData> _mandarinCards = [];
  List<_CardData> _indonesianCards = [];

  int? _selectedMandarinIndex;
  int? _selectedIndonesianIndex;
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
        isMatched: false,
      );
    }).toList()..shuffle(rng);

    // 4 Kartu Bahasa Indonesia
    final indoList = chosenWords.map((item) {
      return _CardData(
        vocabId: item.id,
        mainText: item.artiIndonesia,
        subText: 'Indonesia',
        isMatched: false,
      );
    }).toList()..shuffle(rng);

    setState(() {
      _mandarinCards = mandarinList;
      _indonesianCards = indoList;
      _selectedMandarinIndex = null;
      _selectedIndonesianIndex = null;
      _isChecking = false;
      _roundComplete = false;
      _usedHintThisRound = false;
    });
  }

  void _onTapMandarinCard(int index) {
    if (_isChecking || _roundComplete) return;
    if (_mandarinCards[index].isMatched) return;

    setState(() {
      if (_selectedMandarinIndex == index) {
        _selectedMandarinIndex = null;
      } else {
        _selectedMandarinIndex = index;
      }
    });

    _checkMatchIfBothSelected();
  }

  void _onTapIndonesianCard(int index) {
    if (_isChecking || _roundComplete) return;
    if (_indonesianCards[index].isMatched) return;

    setState(() {
      if (_selectedIndonesianIndex == index) {
        _selectedIndonesianIndex = null;
      } else {
        _selectedIndonesianIndex = index;
      }
    });

    _checkMatchIfBothSelected();
  }

  void _checkMatchIfBothSelected() {
    final mIndex = _selectedMandarinIndex;
    final iIndex = _selectedIndonesianIndex;

    if (mIndex == null || iIndex == null) return;

    final mCard = _mandarinCards[mIndex];
    final iCard = _indonesianCards[iIndex];

    _isChecking = true;

    if (mCard.vocabId == iCard.vocabId) {
      // ✅ Cocok!
      setState(() {
        _mandarinCards[mIndex] = mCard.copyWith(isMatched: true);
        _indonesianCards[iIndex] = iCard.copyWith(isMatched: true);
        _selectedMandarinIndex = null;
        _selectedIndonesianIndex = null;
        _isChecking = false;
      });

      // Cek apakah semua 4 pasang sudah cocok
      final allMatched = _mandarinCards.every((c) => c.isMatched) &&
          _indonesianCards.every((c) => c.isMatched);

      if (allMatched) {
        if (!_usedHintThisRound) {
          _consecutiveWins++;
        }
        _onRoundComplete();
      }
    } else {
      // ❌ Salah, beri feedback merah sesaat lalu batalkan seleksi
      setState(() {
        _mandarinCards[mIndex] = mCard.copyWith(isError: true);
        _indonesianCards[iIndex] = iCard.copyWith(isError: true);
      });

      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _mandarinCards[mIndex] = mCard.copyWith(isError: false);
          _indonesianCards[iIndex] = iCard.copyWith(isError: false);
          _selectedMandarinIndex = null;
          _selectedIndonesianIndex = null;
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
        const SnackBar(content: Text('Koin tidak cukup (butuh 30 💎)')),
      );
      return;
    }

    // Cari pasangan yang belum cocok
    int? targetVocabId;
    int? mIndex;
    int? iIndex;

    for (int i = 0; i < _mandarinCards.length; i++) {
      if (!_mandarinCards[i].isMatched) {
        targetVocabId = _mandarinCards[i].vocabId;
        mIndex = i;
        break;
      }
    }

    if (targetVocabId == null || mIndex == null) return;

    for (int i = 0; i < _indonesianCards.length; i++) {
      if (!_indonesianCards[i].isMatched &&
          _indonesianCards[i].vocabId == targetVocabId) {
        iIndex = i;
        break;
      }
    }

    if (iIndex == null) return;

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
      _mandarinCards[mIndex!] = _mandarinCards[mIndex].copyWith(isMatched: true);
      _indonesianCards[iIndex!] = _indonesianCards[iIndex].copyWith(isMatched: true);
      _selectedMandarinIndex = null;
      _selectedIndonesianIndex = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💡 Bantuan digunakan (-30 💎)! 1 pasang dicocokkan.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
    }

    final allMatched = _mandarinCards.every((c) => c.isMatched) &&
        _indonesianCards.every((c) => c.isMatched);

    if (allMatched) {
      _onRoundComplete();
    }
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
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('🇨🇳', style: TextStyle(fontSize: 14)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Mandarin (4 Kartu)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('🇮🇩', style: TextStyle(fontSize: 14)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Indonesia (4 Kartu)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: _buildMatchingBoard()),
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

  Widget _buildMatchingBoard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kolom Kiri: 4 Kartu Mandarin
          Expanded(
            child: Column(
              children: List.generate(
                _mandarinCards.length,
                (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildCardTile(
                      card: _mandarinCards[i],
                      isSelected: _selectedMandarinIndex == i,
                      isMandarin: true,
                      onTap: () => _onTapMandarinCard(i),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Kolom Kanan: 4 Kartu Bahasa Indonesia
          Expanded(
            child: Column(
              children: List.generate(
                _indonesianCards.length,
                (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildCardTile(
                      card: _indonesianCards[i],
                      isSelected: _selectedIndonesianIndex == i,
                      isMandarin: false,
                      onTap: () => _onTapIndonesianCard(i),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile({
    required _CardData card,
    required bool isSelected,
    required bool isMandarin,
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
      bgColor = isMandarin ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7);
      borderColor = isMandarin ? AppColors.primaryDark : const Color(0xFFD97706);
      borderWidth = 2.5;
    }

    return GestureDetector(
      onTap: card.isMatched ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
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
                if (isMandarin) ...[
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
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primaryGreen,
                      size: 18,
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
    final willGetBonus = _consecutiveWins % 5 == 0 && _consecutiveWins > 0;

    return ScaleTransition(
      scale: _successScale,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const MascotWidget(pose: MascotPose.celebrating, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _consecutiveWins > 0
                        ? '🎉 Hebat! Streak $_consecutiveWins Ronde!'
                        : '✅ Semua 4 Pasang Cocok!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    willGetBonus
                        ? 'Hadiah 25 💎 streak berhasil didapatkan!'
                        : 'Capai kelipatan 5 streak untuk bonus 25 💎 koin!',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextRound() {
    _dealNewRound();
    _successController.reset();
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
  final bool isMatched;
  final bool isError;

  const _CardData({
    required this.vocabId,
    required this.mainText,
    required this.subText,
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
      isMatched: isMatched ?? this.isMatched,
      isError: isError ?? this.isError,
    );
  }
}
