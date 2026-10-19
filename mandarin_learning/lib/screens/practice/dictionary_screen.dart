import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/audio_service.dart';
import '../lesson/vocabulary_detail_screen.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _searchController = TextEditingController();
  int _selectedHskFilter = 0; // 0 = Semua level

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
    if (query.isEmpty) {
      if (_selectedHskFilter == 0) {
        results = vocab.currentLevelVocabulary;
      } else {
        results = vocab.currentLevelVocabulary.where((item) => item.hskLevel == _selectedHskFilter).toList();
      }
    } else {
      results = vocab.searchResults;
      if (_selectedHskFilter > 0) {
        results = results.where((item) => item.hskLevel == _selectedHskFilter).toList();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Kamus Mandarin'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              vocab.setSearchQuery('');
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // HSK Level Filters
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip('Semua Level', 0),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Menampilkan ${results.length} kosakata',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
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
                          const Text('🔍', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada kosakata ditemukan untuk "$query"',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final item = results[index];
                        return _buildWordCard(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int level) {
    final isSelected = _selectedHskFilter == level;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedHskFilter = level;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildWordCard(VocabularyItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              item.hanzi,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              item.pinyin,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'HSK ${item.hskLevel}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            item.artiIndonesia,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryDark, size: 22),
              onPressed: () => AudioService.instance.speak(item.hanzi),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VocabularyDetailScreen(item: item)),
          );
        },
      ),
    );
  }
}
