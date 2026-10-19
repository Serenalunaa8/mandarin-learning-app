import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../models/vocabulary_model.dart';
import '../../widgets/mascot_widget.dart';

// FR-07: Hanzi Matching — cocokkan Hanzi dengan arti, streak bonus koin
// FR-18: Bonus 25 koin tiap 5 beruntun (idempotent per streak milestone)
// FR-19: Bantuan 30 koin — eliminasi pasangan yang salah

class HanziMatchingScreen extends StatefulWidget {
  const HanziMatchingScreen({super.key});

  @override
  State<HanziMatchingScreen> createState() => _HanziMatchingScreenState();
}

class _HanziMatchingScreenState extends State<HanziMatchingScreen>
    with TickerProviderStateMixin {
  static const int _pairCount = 4; // 4 pasang kartu = 8 kartu total

  List<_MatchCard> _cards = [];
  List<bool> _flipped = [];
  List<bool> _matched = [];
  int? _firstSelectedIndex;
  bool _isChecking = false;

  int _consecutiveWins = 0; // streak
  final Set<int> _awardedStreakMilestones = {}; // FR-18 idempotent
  bool _roundComplete = false;

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
    if (words.isEmpty) {
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
    final pairs = shuffled.take(_pairCount).toList();

    final List<_MatchCard> cards = [];
    for (var item in pairs) {
      cards.add(
        _MatchCard(
          id: item.id,
          text: item.hanzi,
          type: CardType.hanzi,
          vocabId: item.id,
        ),
      );
      cards.add(
        _MatchCard(
          id: item.id,
          text: item.artiIndonesia,
          type: CardType.meaning,
          vocabId: item.id,
        ),
      );
    }
    cards.shuffle(rng);

    setState(() {
      _cards = cards;
      _flipped = List.filled(cards.length, false);
      _matched = List.filled(cards.length, false);
      _firstSelectedIndex = null;
      _isChecking = false;
      _roundComplete = false;
    });
  }

  void _onTapCard(int index) {
    if (_isChecking) return;
    if (_matched[index]) return;
    if (_flipped[index]) return; // already selected

    setState(() => _flipped[index] = true);

    if (_firstSelectedIndex == null) {
      _firstSelectedIndex = index;
      return;
    }

    // Second card selected — check match
    final first = _firstSelectedIndex!;
    _isChecking = true;

    if (_cards[first].id == _cards[index].id &&
        _cards[first].type != _cards[index].type) {
      // ✅ Correct match
      setState(() {
        _matched[first] = true;
        _matched[index] = true;
        _firstSelectedIndex = null;
      });
      _isChecking = false;

      if (_matched.every((m) => m)) {
        // Round complete
        _consecutiveWins++;
        _onRoundComplete();
      }
    } else {
      // ❌ Wrong — flip back after delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _flipped[first] = false;
          _flipped[index] = false;
          _firstSelectedIndex = null;
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
              '🔥 Streak $_consecutiveWins! Bonus 25 koin streak telah diberikan!',
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
      'streak_bonus',
      'Bonus streak Hanzi Matching ke-$attemptId',
      attemptId: attemptId,
    );
  }

  // FR-19: Bantuan — deduct 30 koin, eliminasi satu pasang yang salah (belum dicocokkan)
  Future<void> _useHint() async {
    final auth = context.read<AuthProvider>();
    final balance = auth.coins;
    if (balance < 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koin tidak cukup (butuh 30 🪙)')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gunakan Bantuan?'),
        content: const Text(
          'Tukarkan 30 koin untuk membuka satu pasangan Hanzi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gunakan 30 koin'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Find an unmatched pair id
    final unmatchedIds = <int>{};
    for (int i = 0; i < _cards.length; i++) {
      if (!_matched[i]) unmatchedIds.add(_cards[i].id);
    }
    if (unmatchedIds.isEmpty) return;

    // Pick random unmatched pair
    final targetId = unmatchedIds.first;
    final deducted = await auth.deductCoins(
      30,
      'hint_matching',
      'Bantuan Hanzi Matching',
      attemptId: 'hint_hanzi_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (!deducted || !mounted) return;

    setState(() {
      for (int i = 0; i < _cards.length; i++) {
        if (_cards[i].id == targetId) {
          _matched[i] = true;
          _flipped[i] = true;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('💡 Bantuan digunakan! -30 🪙')),
    );

    if (_matched.every((m) => m)) {
      _consecutiveWins = 0; // hint used → no streak count for this round
      _onRoundComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final coinBalance = auth.coins;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Hanzi Matching'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '$coinBalance',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pool.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildGrid()),
                _buildBottomBar(),
                if (_roundComplete) _buildRoundCompleteOverlay(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Streak Beruntun',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < (_consecutiveWins % 5)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 20,
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
                'Total Menang',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              Text(
                '$_consecutiveWins ronde',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.7,
        ),
        itemCount: _cards.length,
        itemBuilder: (context, i) => _buildCard(i),
      ),
    );
  }

  Widget _buildCard(int index) {
    final card = _cards[index];
    final isMatched = _matched[index];
    final isFlipped = _flipped[index];
    final isHanzi = card.type == CardType.hanzi;

    Color bgColor;
    if (isMatched) {
      bgColor = const Color(0xFFD1FAE5);
    } else if (isFlipped) {
      bgColor = isHanzi ? const Color(0xFFEFF6FF) : const Color(0xFFFDF2F8);
    } else {
      bgColor = Colors.white;
    }

    return GestureDetector(
      onTap: isMatched || _roundComplete ? null : () => _onTapCard(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMatched
                ? AppColors.primaryGreen
                : isFlipped
                ? AppColors.primaryDark
                : const Color(0xFFE2E8F0),
            width: isFlipped || isMatched ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: isFlipped || isMatched
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isHanzi)
                        Text(
                          card.text,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                          textAlign: TextAlign.center,
                        )
                      else
                        Text(
                          card.text,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textDark,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (isMatched)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.check_circle,
                            color: AppColors.primaryGreen,
                            size: 16,
                          ),
                        ),
                    ],
                  )
                : Icon(
                    isHanzi ? Icons.translate : Icons.abc,
                    color: const Color(0xFFCBD5E1),
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _useHint,
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Bantuan (-30 🪙)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD97706),
                side: const BorderSide(color: Color(0xFFF59E0B)),
                padding: const EdgeInsets.symmetric(vertical: 14),
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
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Ronde Berikutnya'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
    return ScaleTransition(
      scale: _successScale,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryGreen, width: 2),
        ),
        child: Row(
          children: [
            const MascotWidget(pose: MascotPose.celebrating, size: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _consecutiveWins > 0
                        ? '🔥 Streak $_consecutiveWins! Lanjut!'
                        : '✅ Ronde Selesai!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _consecutiveWins % 5 == 0 && _consecutiveWins > 0
                        ? 'Bonus 25 🪙 streak berhasil!'
                        : 'Lanjutkan untuk bonus streak!',
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
            'Belum ada kosakata di level ini.',
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

enum CardType { hanzi, meaning }

class _MatchCard {
  final int id;
  final String text;
  final CardType type;
  final int vocabId;
  const _MatchCard({
    required this.id,
    required this.text,
    required this.type,
    required this.vocabId,
  });
}
