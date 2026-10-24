import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/audio_service.dart';
import '../lesson/vocabulary_detail_screen.dart';

List<VocabularyItem> filterVocabularyByHskLevel(
  List<VocabularyItem> vocabulary,
  int hskLevel,
) {
  if (hskLevel == 0) return vocabulary;
  return vocabulary.where((item) => item.hskLevel == hskLevel).toList();
}

class DictionaryScreen extends StatefulWidget {
  final bool initialShowFavorites;

  const DictionaryScreen({super.key, this.initialShowFavorites = false});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _searchController = TextEditingController();
  late int
  _selectedHskFilter; // 0 = Semua, 1-6 = HSK Level, -1 = Koleksi Kata / Favorit

  @override
  void initState() {
    super.initState();
    _selectedHskFilter = widget.initialShowFavorites ? -1 : 0;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocab = context.watch<VocabularyProvider>();
    final query = _searchController.text.trim();

    List<VocabularyItem> results;
    if (_selectedHskFilter == -1) {
      // Tampilkan kata favorit / tersimpan
      results = vocab.favoriteVocabulary;
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        results = results
            .where(
              (item) =>
                  item.hanzi.toLowerCase().contains(q) ||
                  item.pinyin.toLowerCase().contains(q) ||
                  item.artiIndonesia.toLowerCase().contains(q),
            )
            .toList();
      }
    } else {
      final source = query.isEmpty ? vocab.allVocabulary : vocab.searchResults;
      results = filterVocabularyByHskLevel(source, _selectedHskFilter);
    }

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEAF5E8), Color(0xFFFFFBF2), Color(0xFFEAF4F1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 184,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(34),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, Color(0xFFA8D77D)],
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: 0.58,
                          child: Image.asset(
                            'assets/image/beranda/bg_siang.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x66307836),
                                Color(0x22307836),
                                Color(0x00307836),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 155,
                          top: 30,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: const Text(
                                  'Kamus Mandarin',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x66305A36),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Temukan kata baru setiap hari',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x55305A36),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 48,
                          bottom: 22,
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0x66FFE8A3),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x55FFF4CC),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Positioned(
                          right: 26,
                          top: 34,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 19,
                            color: Color(0xFFFFE899),
                          ),
                        ),
                        Positioned(
                          right: 36,
                          bottom: 5,
                          child: Image.asset(
                            'assets/image/beranda/maskot_02_baca_buku.png',
                            height: 126,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          left: 22,
                          bottom: 22,
                          child: Image.asset(
                            'assets/image/beranda/daun_tunggal.png',
                            width: 23,
                            height: 23,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: -28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(
                              alpha: 0.16,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          vocab.setSearchQuery(val);
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'Cari Hanzi, Pinyin, atau Arti...',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primaryDark,
                            size: 25,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: AppColors.textMuted,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    vocab.setSearchQuery('');
                                    setState(() {});
                                  },
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(13),
                                  child: Image.asset(
                                    'assets/image/beranda/daun_tunggal.png',
                                    width: 22,
                                    height: 22,
                                  ),
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 42),

              // HSK Level Filters + Koleksi Kata Favorit
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 2,
                  ),
                  children: [
                    _buildFilterChip('Semua Level', 0),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      '⭐ Koleksi Kata (${vocab.favoriteVocabIds.length})',
                      -1,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip('HSK 1', 1),
                    const SizedBox(width: 8),
                    _buildFilterChip('HSK 2', 2),
                    const SizedBox(width: 8),
                    _buildFilterChip('HSK 3', 3),
                    const SizedBox(width: 8),
                    _buildFilterChip('HSK 4', 4),
                    const SizedBox(width: 8),
                    _buildFilterChip('HSK 5', 5),
                    const SizedBox(width: 8),
                    _buildFilterChip('HSK 6', 6),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Result count info
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 2, 22, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 22,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedHskFilter == -1
                          ? 'Koleksi ${results.length} kosakata tersimpan'
                          : 'Menampilkan ${results.length} kosakata',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // Word List
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _selectedHskFilter == -1 ? '⭐' : '🔍',
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedHskFilter == -1
                                  ? 'Belum ada kosakata di Koleksi Kata.\nKetuk ikon bintang pada kata untuk menyimpannya.'
                                  : 'Tidak ada kosakata ditemukan untuk "$query"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final item = results[index];
                          return _buildWordCard(context, item, vocab, results);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int level) {
    final isSelected = _selectedHskFilter == level;
    final accentColor = _levelAccent(level);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedHskFilter = level;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accentColor.withValues(alpha: isSelected ? 1 : 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isSelected ? 0.2 : 0.08),
              blurRadius: isSelected ? 10 : 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (level == -1)
              Icon(
                Icons.star_rounded,
                size: 17,
                color: isSelected ? Colors.white : AppColors.coinGold,
              )
            else
              Icon(
                Icons.eco_rounded,
                size: 17,
                color: isSelected ? Colors.white : accentColor,
              ),
            const SizedBox(width: 6),
            Text(
              label.replaceFirst('⭐ ', ''),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF415B53),
              ),
            ),
            if (level > 0) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: isSelected ? Colors.white : accentColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _levelAccent(int level) {
    return switch (level) {
      -1 => AppColors.coinGold,
      0 => AppColors.primaryDark,
      1 => const Color(0xFFE76F51),
      2 => const Color(0xFF398A9A),
      3 => const Color(0xFF5184B8),
      4 => AppColors.coinGold,
      5 => const Color(0xFF6D9B53),
      6 => const Color(0xFF8B6B9E),
      _ => AppColors.primaryDark,
    };
  }

  Widget _buildWordCard(
    BuildContext context,
    VocabularyItem item,
    VocabularyProvider vocab,
    List<VocabularyItem> results,
  ) {
    final isFav = vocab.isFavorite(item.id);
    final levelAccent = _levelAccent(item.hskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Color(0xFFFCFFFA)],
        ),
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(27),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    VocabularyDetailScreen(item: item, vocabularyList: results),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFFBF2), Color(0xFFEAF5E8)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: levelAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.hanzi,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: levelAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            item.pinyin,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF344B50),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: levelAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'HSK ${item.hskLevel}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ).copyWith(color: levelAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.artiIndonesia,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.25,
                          color: Color(0xFF8096A8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                _buildWordAction(
                  icon: isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFav ? AppColors.coinGold : const Color(0xFF93A9BD),
                  tooltip: isFav ? 'Hapus dari koleksi' : 'Simpan ke koleksi',
                  onPressed: () => vocab.toggleFavorite(item.id),
                ),
                _buildWordAction(
                  icon: Icons.volume_up_rounded,
                  color: const Color(0xFF3F83D7),
                  tooltip: 'Dengarkan pelafalan',
                  onPressed: () => AudioService.instance.speak(item.hanzi),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8DA4B5),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      icon: Icon(icon, color: color, size: 23),
      onPressed: onPressed,
    );
  }
}
