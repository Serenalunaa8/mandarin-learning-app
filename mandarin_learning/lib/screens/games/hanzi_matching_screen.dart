import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/audio_service.dart';
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

  List<_CardData> _cards = [];
  int? _selectedCardIndex;
  bool _isChecking = false;

  int _consecutiveWins = 0; // streak
  final Set<int> _awardedStreakMilestones = {}; // FR-18 idempotent
  bool _roundComplete = false;
  bool _usedHintThisRound = false;

  // Mascot dynamic reaction
  // true = correct reaction, false = wrong reaction, null = normal state
  bool? _mascotReaction;
  Timer? _reactionTimer;

  late AnimationController _successController;
  late Animation<double> _successScale;

  List<VocabularyItem> _pool = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _successScale = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndDeal());
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
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

  void _triggerMascotReaction({required bool isCorrect}) {
    _reactionTimer?.cancel();
    setState(() {
      _mascotReaction = isCorrect;
    });
    _reactionTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        _mascotReaction = null;
      });
    });
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
    }).toList()..shuffle(rng);

    // 4 Kartu Bahasa Indonesia
    final indoList = chosenWords.map((item) {
      return _CardData(
        vocabId: item.id,
        mainText: item.artiIndonesia,
        subText: 'Indonesia',
        isMandarin: false,
        isMatched: false,
      );
    }).toList()..shuffle(rng);

    // Susun secara interleaved agar kolom kiri selalu Mandarin dan kolom kanan selalu Indonesia
    final allCards = <_CardData>[];
    for (var i = 0; i < _pairCount; i++) {
      allCards.add(mandarinList[i]);
      allCards.add(indoList[i]);
    }

    setState(() {
      _cards = allCards;
      _selectedCardIndex = null;
      _isChecking = false;
      _roundComplete = false;
      _usedHintThisRound = false;
      _mascotReaction = null;
    });
  }

  void _onTapCard(int index) {
    if (_isChecking || _roundComplete) return;
    if (_cards[index].isMatched) return;

    final tappedCard = _cards[index];

    // Jika menyentuh kartu Mandarin, bunyikan pengucapan audio
    if (tappedCard.isMandarin) {
      AudioService.instance.speak(tappedCard.mainText);
    }

    if (_selectedCardIndex == null) {
      setState(() {
        _selectedCardIndex = index;
      });
      return;
    }

    if (_selectedCardIndex == index) {
      // Klik kartu yang sama -> batalkan pilihan
      setState(() {
        _selectedCardIndex = null;
      });
      return;
    }

    final firstIndex = _selectedCardIndex!;
    final firstCard = _cards[firstIndex];
    final secondCard = _cards[index];

    // Jika kedua kartu sama bahasa (Mandarin & Mandarin atau Indo & Indo), pindahkan seleksi
    if (firstCard.isMandarin == secondCard.isMandarin) {
      setState(() {
        _selectedCardIndex = index;
      });
      return;
    }

    _isChecking = true;

    if (firstCard.vocabId == secondCard.vocabId) {
      // ✅ Cocok!
      final mandarinText = firstCard.isMandarin ? firstCard.mainText : secondCard.mainText;
      AudioService.instance.speak(mandarinText);

      setState(() {
        _cards[firstIndex] = firstCard.copyWith(isMatched: true);
        _cards[index] = secondCard.copyWith(isMatched: true);
        _selectedCardIndex = null;
        _isChecking = false;
      });

      _triggerMascotReaction(isCorrect: true);

      // Cek apakah semua 8 kartu telah cocok
      if (_cards.every((c) => c.isMatched)) {
        if (!_usedHintThisRound) {
          _consecutiveWins++;
        }
        _onRoundComplete();
      }
    } else {
      // ❌ Salah, beri efek merah sesaat lalu batalkan seleksi
      _triggerMascotReaction(isCorrect: false);

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
    setState(() {
      _roundComplete = true;
    });
    _successController.forward(from: 0);

    // FR-18: bonus 25 koin tiap 5 beruntun (idempotent)
    final milestone = (_consecutiveWins ~/ 5) * 5;
    if (milestone > 0 && !_awardedStreakMilestones.contains(milestone)) {
      _awardedStreakMilestones.add(milestone);
      await _addCoins(25, 'hanzi_matching_streak_$milestone');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Image.asset('assets/image/beranda/koin.png', width: 22, height: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🔥 Streak $_consecutiveWins! Bonus 25 koin streak berhasil diraih!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        SnackBar(
          content: Row(
            children: [
              Image.asset('assets/image/beranda/koin.png', width: 20, height: 20),
              const SizedBox(width: 8),
              const Text('Koin tidak cukup! Butuh 30 koin untuk bantuan.'),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    final matchedMandarin = _cards[mIndex];
    AudioService.instance.speak(matchedMandarin.mainText);

    setState(() {
      _cards[mIndex!] = _cards[mIndex].copyWith(isMatched: true);
      _cards[iIndex!] = _cards[iIndex].copyWith(isMatched: true);
      _selectedCardIndex = null;
    });

    _triggerMascotReaction(isCorrect: true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Image.asset('assets/image/beranda/koin.png', width: 20, height: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('💡 Bantuan digunakan (-30 koin)! 1 pasang otomatis cocok.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: const Color(0xFFF0FDF4),
      body: Stack(
        children: [
          // Latar Belakang Alam Lembut & Awan dari assets
          Positioned.fill(
            child: Opacity(
              opacity: 0.18,
              child: Image.asset(
                'assets/image/games/background_1_padang_cerah.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            top: -15,
            right: -25,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/image/beranda/awan_kecil.png',
                width: 150,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            top: 90,
            left: -35,
            child: Opacity(
              opacity: 0.28,
              child: Image.asset(
                'assets/image/beranda/awan_besar.png',
                width: 170,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Konten Utama
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(auth.coins),
                if (!_isLoading && _pool.length >= _pairCount) ...[
                  _buildMascotCompanionCard(),
                  const SizedBox(height: 2),
                  Expanded(child: _buildMatchingGrid()),
                  _buildBottomBar(),
                ] else if (_isLoading) ...[
                  const Expanded(child: Center(child: CircularProgressIndicator())),
                ] else ...[
                  Expanded(child: _buildEmptyState()),
                ],
              ],
            ),
          ),

          // Dialog Kemenangan
          if (_roundComplete) _buildRoundCompleteOverlay(),
        ],
      ),
    );
  }

  Widget _buildAppBar(int coins) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          // Tombol Kembali
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF334155),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Judul dengan Ikon Game (Tanpa Subtitle)
          Expanded(
            child: Row(
              children: [
                Image.asset(
                  'assets/image/icon_beranda/hanzi_matching.png',
                  width: 32,
                  height: 32,
                  errorBuilder: (_, __, ___) => const Text('🧩', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Hanzi Matching',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          // Saldo Koin
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/image/beranda/koin.png',
                  width: 18,
                  height: 18,
                  errorBuilder: (_, __, ___) => const Text('🪙', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 6),
                Text(
                  '$coins',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotCompanionCard() {
    final matchedPairs = _cards.where((c) => c.isMatched).length ~/ 2;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Maskot Interaktif dengan reaksi dinamis
          _buildInteractiveMascot(),
          const SizedBox(width: 12),

          // Indikator Angka Pasangan (1, 2, 3, 4) & Streak
          Expanded(
            child: Row(
              children: [
                ...List.generate(_pairCount, (i) {
                  final isMatched = i < matchedPairs;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: EdgeInsets.only(right: i < _pairCount - 1 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isMatched ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isMatched ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                          width: isMatched ? 1.8 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: isMatched
                            ? const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Color(0xFF15803D),
                              )
                            : Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 10),

                // Streak Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFEDD5), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '$_consecutiveWins',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveMascot() {
    String assetPath = 'assets/image/games/Excited Green Frog Mascot.png';
    if (_mascotReaction == true) {
      assetPath = 'assets/image/games/Blushing Green Sprout Mascot.png';
    } else if (_mascotReaction == false) {
      assetPath = 'assets/image/games/Crying Green Frog Chibi Mascot.png';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey<String>(assetPath),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _mascotReaction == true
              ? const Color(0xFFECFDF5)
              : (_mascotReaction == false
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFF8FAFC)),
          shape: BoxShape.circle,
          border: Border.all(
            color: _mascotReaction == true
                ? const Color(0xFF10B981)
                : (_mascotReaction == false
                    ? const Color(0xFFF87171)
                    : const Color(0xFFE2E8F0)),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => MascotWidget(
            pose: _mascotReaction == true
                ? MascotPose.celebrating
                : (_mascotReaction == false
                    ? MascotPose.holdingSign
                    : MascotPose.waving),
            size: 40,
          ),
        ),
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
          const spacing = 11.0;
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;
          final itemWidth = (availableWidth - spacing) / crossAxisCount;
          final itemHeight = (availableHeight - (rows - 1) * spacing) / rows;
          final ratio = (itemWidth / itemHeight).clamp(0.9, 2.8);

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
    // Warna & Gaya Kartu berdasarkan status
    Color bgColor;
    Color borderColor;
    Color shadowColor;
    Color textColor;
    double borderWidth = 1.8;
    double bevelOffset = 4.0;

    if (card.isMatched) {
      // ✅ Status Pasangan Cocok: Hijau mint segar seragam & rapi
      bgColor = const Color(0xFFDCFCE7);
      borderColor = const Color(0xFF16A34A);
      shadowColor = const Color(0xFF16A34A).withValues(alpha: 0.2);
      textColor = const Color(0xFF15803D);
      borderWidth = 2.0;
      bevelOffset = 2.0;
    } else if (card.isError) {
      // ❌ Status Salah: Rose Coral Red
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFEF4444);
      shadowColor = const Color(0xFFEF4444).withValues(alpha: 0.2);
      textColor = const Color(0xFFB91C1C);
      borderWidth = 2.2;
      bevelOffset = 2.0;
    } else if (isSelected) {
      // 🔍 Status Terpilih: Glow cerah sesuai bahasa kartu
      if (card.isMandarin) {
        bgColor = const Color(0xFFEDE9FE); // Lavender Indigo Glow
        borderColor = const Color(0xFF7C3AED);
        shadowColor = const Color(0xFF7C3AED).withValues(alpha: 0.3);
        textColor = const Color(0xFF4C1D95);
      } else {
        bgColor = const Color(0xFFFEF3C7); // Warm Amber Gold Glow
        borderColor = const Color(0xFFD97706);
        shadowColor = const Color(0xFFD97706).withValues(alpha: 0.3);
        textColor = const Color(0xFF78350F);
      }
      borderWidth = 2.6;
      bevelOffset = 2.0;
    } else {
      // ⚪ Status Normal: Dual-Tone Selaras (Mandarin Violet-Slate vs Indonesia Warm-Amber)
      if (card.isMandarin) {
        bgColor = const Color(0xFFFAF5FF); // Soft Lavender Tint
        borderColor = const Color(0xFFDDD6FE); // Soft Violet Border
        shadowColor = const Color(0xFFC4B5FD); // 3D Bevel Shadow
        textColor = const Color(0xFF312E81); // Deep Indigo Hanzi
      } else {
        bgColor = const Color(0xFFFFFDF5); // Soft Honey Cream Tint
        borderColor = const Color(0xFFFDE68A); // Warm Amber Border
        shadowColor = const Color(0xFFFCD34D); // 3D Bevel Shadow
        textColor = const Color(0xFF1E293B); // Clean Dark Slate
      }
    }

    return GestureDetector(
      onTap: card.isMatched ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: Offset(0, bevelOffset),
              blurRadius: isSelected ? 8 : 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Baris Header Mini Kartu (Badge Jenis & Ikon Centang saat cocok)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badge Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: card.isMatched
                            ? const Color(0xFFBBF7D0)
                            : (card.isMandarin
                                ? const Color(0xFFEDE9FE)
                                : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        card.isMatched
                            ? '✓ Cocok'
                            : (card.isMandarin ? '🀄 Hanzi' : '🇮🇩 Arti'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: card.isMatched
                              ? const Color(0xFF166534)
                              : (card.isMandarin
                                  ? const Color(0xFF6D28D9)
                                  : const Color(0xFFB45309)),
                        ),
                      ),
                    ),

                    // Centang Sukses saat Cocok
                    if (card.isMatched)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF16A34A),
                      )
                    else
                      const SizedBox(width: 16),
                  ],
                ),

                // Teks Utama Kartu
                Expanded(
                  child: Center(
                    child: card.isMandarin
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  card.mainText,
                                  style: TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  card.subText,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: card.isMatched
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF6D28D9),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              card.mainText,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                height: 1.25,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ),
                ),

                // Feedback status saat error
                if (card.isError)
                  const Text(
                    '✕ Coba lagi',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  )
                else
                  const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Tombol Bantuan Koin
          Expanded(
            child: OutlinedButton(
              onPressed: _roundComplete ? null : _useHint,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB45309),
                backgroundColor: const Color(0xFFFFFBEB),
                side: const BorderSide(color: Color(0xFFFCD34D), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  const Text(
                    'Bantuan (-30 ',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  Image.asset(
                    'assets/image/beranda/koin.png',
                    width: 16,
                    height: 16,
                    errorBuilder: (_, __, ___) => const Text('🪙', style: TextStyle(fontSize: 12)),
                  ),
                  const Text(
                    ')',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Tombol Ronde Berikutnya
          Expanded(
            child: ElevatedButton(
              onPressed: _roundComplete ? _nextRound : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: const Color(0xFF94A3B8),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: _roundComplete ? 4 : 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Berikutnya',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
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
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: ScaleTransition(
          scale: _successScale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF86EFAC), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Maskot Perayaan dengan Sparkles
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -12,
                      right: -16,
                      child: Image.asset(
                        'assets/image/beranda/kilau_01.png',
                        width: 38,
                        height: 38,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    Positioned(
                      bottom: -8,
                      left: -14,
                      child: Image.asset(
                        'assets/image/beranda/kilau_02.png',
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    Container(
                      width: 95,
                      height: 95,
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(
                        'assets/image/games/Excited Green Frog Mascot.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const MascotWidget(
                          pose: MascotPose.celebrating,
                          size: 75,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'Luar Biasa! 🎉',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF065F46),
                    letterSpacing: -0.3,
                  ),
                ),

                // Milestone Streak Bonus jika tercapai
                if (isStreakMilestone) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/image/beranda/koin.png', width: 22, height: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Streak Milestone $_consecutiveWins! +25 Koin 🎁',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF92400E),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Tombol Lanjut Ronde
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextRound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Berikutnya',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/image/games/Crying Green Frog Chibi Mascot.png',
              width: 100,
              height: 100,
              errorBuilder: (_, __, ___) => const MascotWidget(
                pose: MascotPose.holdingSign,
                size: 90,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada kosakata yang cukup di level ini.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Kembali'),
            ),
          ],
        ),
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
