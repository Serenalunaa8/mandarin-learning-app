import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/avatar_image_helper.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _messageController = TextEditingController();
  int _rating = 5;
  String _selectedCategory = 'Materi Kosakata';
  bool _isSubmitting = false;
  bool _isLoadingFeedbacks = true;
  List<Map<String, dynamic>> _feedbackList = [];

  final List<String> _categories = [
    'Materi Kosakata',
    'Kuis & Latihan',
    'Pelafalan & Analisis Nada',
    'AI Tutor',
    'Mini-Game & Sensor',
    'Performa / Bug Aplikasi',
    'Saran & Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
    _messageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadFeedbacks() async {
    setState(() {
      _isLoadingFeedbacks = true;
    });

    final data = await SupabaseService.instance.fetchFeedbacks();

    if (mounted) {
      setState(() {
        _feedbackList = data;
        _isLoadingFeedbacks = false;
      });
    }
  }

  String _getRatingFeedbackText(int rating) {
    switch (rating) {
      case 5:
        return 'Sangat Puas! (太棒了)';
      case 4:
        return 'Bagus & Bermanfaat';
      case 3:
        return 'Cukup Baik';
      case 2:
        return 'Perlu Peningkatan';
      default:
        return 'Kurang Memuaskan';
    }
  }

  String _getAccountName(AuthProvider auth) {
    final user = auth.profile;
    if (user?.fullName != null && user!.fullName.trim().isNotEmpty) {
      return user.fullName.trim();
    }
    if (user?.username != null && user!.username.trim().isNotEmpty) {
      return user.username.trim();
    }
    return auth.isGuest ? 'Tamu' : 'Pelajar';
  }

  void _handleSubmit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan tuliskan pesan atau saran Anda terlebih dahulu.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final auth = context.read<AuthProvider>();
    final userId = auth.profile?.id;
    final accountName = _getAccountName(auth);

    final success = await SupabaseService.instance.submitFeedback(
      userId: userId,
      accountName: accountName,
      category: _selectedCategory,
      message: message,
      rating: _rating,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (!mounted) return;

    if (success) {
      _messageController.clear();
      FocusScope.of(context).unfocus();

      // Tambahkan item secara langsung di urutan teratas agar langsung tampil
      setState(() {
        _feedbackList.insert(0, {
          'account_name': accountName,
          'category': _selectedCategory,
          'message': message,
          'rating': _rating,
          'created_at': DateTime.now().toIso8601String(),
          'app_users': {
            'full_name': accountName,
            'avatar_url': auth.profile?.avatarUrl,
          },
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Terima kasih! Masukan Anda berhasil dikirim dan ditampilkan.')),
            ],
          ),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadFeedbacks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengirim umpan balik. Periksa koneksi internet.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Baru saja';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
      if (diff.inHours < 24) return '${diff.inHours}j lalu';
      if (diff.inDays < 7) return '${diff.inDays}h lalu';

      final day = dt.day.toString().padLeft(2, '0');
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final month = months[dt.month - 1];
      return '$day $month ${dt.year}';
    } catch (_) {
      return 'Baru saja';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF5),
      body: SafeArea(
        child: Stack(
          children: [
            // Konten Utama Scrollable
            RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadFeedbacks,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // Header Bar Atas dengan Maskot Bintang
                  SliverToBoxAdapter(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Hiasan bukit rumput lembut di latar belakang atas
                        Positioned(
                          top: -30,
                          left: -20,
                          right: -20,
                          height: 120,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFDDF4E4).withValues(alpha: 0.6),
                                  const Color(0xFFF3FAF5).withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),

                        // Maskot Bintang di pojok kanan atas (sesuai referensi gambar)
                        Positioned(
                          top: 4,
                          right: 12,
                          child: IgnorePointer(
                            child: Image.asset(
                              'assets/image/beranda/maskot_01_bintang.png',
                              width: 82,
                              height: 82,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                          ),
                        ),

                        // Tombol Kembali & Judul Halaman
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            children: [
                              // Tombol Kembali Berbentuk Lingkaran Mint
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFDCFCE7),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1E3A24).withValues(alpha: 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.arrow_back_rounded,
                                      color: Color(0xFF16A34A),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Judul "Umpan Balik & Saran"
                              const Text(
                                'Umpan Balik & Saran',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A24),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Konten Form Utama
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // Kartu 1: "Bantu Kami Berkembang"
                          _buildIntroCard(),
                          const SizedBox(height: 16),

                          // Kartu 2: Rating Pengalaman Belajar
                          _buildRatingCard(),
                          const SizedBox(height: 20),

                          // Bagian Kategori Masukan
                          _buildSectionHeader(
                            icon: Icons.local_offer_rounded,
                            title: 'Kategori Masukan',
                          ),
                          const SizedBox(height: 10),
                          _buildCategoryDropdown(),
                          const SizedBox(height: 20),

                          // Bagian Pesan / Saran / Laporan Masalah
                          _buildSectionHeader(
                            icon: Icons.edit_rounded,
                            title: 'Pesan / Saran / Laporan Masalah',
                          ),
                          const SizedBox(height: 10),
                          _buildMessageInput(),
                          const SizedBox(height: 20),

                          // Tombol Kirim Masukan
                          _buildSubmitButton(),
                          const SizedBox(height: 28),

                          // Header Daftar Masukan Langsung di Bawahnya
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.forum_rounded,
                                  color: Color(0xFF16A34A),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Masukan & Ulasan Terbaru',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A24),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_feedbackList.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // Daftar Feedback yang Langsung Ditampilkan
                  _buildFeedbackList(),

                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 32),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== WIDGET COMPONENTS =====================

  /// Kartu 1: "Bantu Kami Berkembang"
  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8F5E9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A24).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Lingkaran Hijau Mint dengan Kepala Maskot
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F8EE),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'assets/image/register/09_mascot_head.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.pets_rounded,
                  color: Color(0xFF16A34A),
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Teks Judul & Deskripsi
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bantu Kami Berkembang',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A24),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Kritik dan saran kamu membantu meningkatkan kualitas pembelajaran Mandarin.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Speech bubble dengan ikon hati kuning & daun (sesuai referensi)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFEF08A), width: 1.2),
                ),
                child: const Center(
                  child: Text(
                    '💛',
                    style: TextStyle(fontSize: 22),
                  ),
                ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Image.asset(
                  'assets/image/beranda/daun_tunas.png',
                  width: 18,
                  height: 18,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Kartu 2: Rating Pengalaman Belajar
  Widget _buildRatingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8F5E9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A24).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ilustrasi papan checklist / smiley di kanan kartu (sesuai referensi)
          Positioned(
            right: 0,
            bottom: -6,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.95,
                child: Container(
                  width: 78,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFCE8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFEF08A), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Clip atas papan
                      Positioned(
                        top: -6,
                        child: Container(
                          width: 28,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF60A5FA),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 6),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF9C3),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('😊', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 44,
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 30,
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      // Daun di samping clipboard
                      Positioned(
                        bottom: -4,
                        right: -6,
                        child: Image.asset(
                          'assets/image/beranda/daun_tunas.png',
                          width: 24,
                          height: 24,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Konten Utama Rating
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Pertanyaan dengan Ikon Bintang Bulat
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF08A),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.star_rounded,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Bagaimana pengalaman belajarmu sejauh ini?',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A24),
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 80), // Berikan ruang untuk ilustrasi papan di kanan
                ],
              ),
              const SizedBox(height: 14),

              // Baris Bintang Rating Interaktif
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  final isSelected = starValue <= _rating;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = starValue;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: isSelected ? 1.08 : 0.95,
                        child: Icon(
                          Icons.star_rounded,
                          size: 38,
                          color: isSelected ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              // Pill Status Kepuasan dengan Kilau
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBFDF2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF16A34A),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getRatingFeedbackText(_rating),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section Header dengan Icon Hijau & Judul
  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF16A34A), size: 19),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A24),
          ),
        ),
      ],
    );
  }

  /// Dropdown Pilihan Kategori Masukan
  Widget _buildCategoryDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          icon: const Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF1E3A24),
              size: 24,
            ),
          ),
          items: _categories.map((cat) {
            return DropdownMenuItem<String>(
              value: cat,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    // Ikon Buku Berlatar Hijau Mint (sesuai referensi)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/image/beranda/ikon_buku.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.menu_book_rounded,
                            color: Color(0xFF16A34A),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedCategory = val;
              });
            }
          },
        ),
      ),
    );
  }

  /// Kotak Input Pesan dengan Dekorasi Daun & Counter Karakter
  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Input Teks
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
            child: TextField(
              controller: _messageController,
              maxLines: 5,
              minLines: 4,
              maxLength: 500,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF1E293B),
                height: 1.45,
              ),
              decoration: const InputDecoration(
                hintText: 'Tuliskan secara jelas kendala materi, audio, arti kata, atau ide fitur baru...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Hiasan Daun dan Bunga di Pojok Kiri Bawah (sesuai referensi)
          Positioned(
            bottom: 4,
            left: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/image/beranda/daun_tunas.png',
                  width: 22,
                  height: 22,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
                Transform.translate(
                  offset: const Offset(-6, 2),
                  child: Image.asset(
                    'assets/image/beranda/bunga_putih.png',
                    width: 16,
                    height: 16,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),

          // Penghitung Karakter (0/500) di Pojok Kanan Bawah
          Positioned(
            bottom: 10,
            right: 14,
            child: Text(
              '${_messageController.text.length}/500',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tombol Kirim Masukan Berbentuk Pill Hijau
  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        onPressed: _isSubmitting ? null : _handleSubmit,
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Kirim Masukan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Daftar Feedback yang Ditampilkan Langsung
  Widget _buildFeedbackList() {
    if (_isLoadingFeedbacks) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (_feedbackList.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/image/beranda/bubel_nihao.png',
                  width: 50,
                  height: 50,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 36,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Belum ada ulasan tersimpan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A24),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Jadilah yang pertama memberikan masukan untuk pengembangan aplikasi!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _feedbackList[index];
            final accountName = (item['account_name'] ??
                    item['app_users']?['full_name'] ??
                    item['app_users']?['username'] ??
                    'Pelajar')
                .toString();
            final category = (item['category'] ?? 'Saran').toString();
            final message = (item['message'] ?? '').toString();
            final rating = (item['rating'] as num?)?.toInt() ?? 5;
            final dateStr = _formatTimestamp(item['created_at']?.toString());
            final initial = accountName.isNotEmpty ? accountName[0].toUpperCase() : 'P';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8F5E9), width: 1.1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A24).withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Baris Atas: Avatar + Nama Akun + Rating Bintang
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFFDCFCE7),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              accountName,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Rating Bintang Mini
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (sIdx) {
                          return Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: sIdx < rating ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Kategori Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBFDF2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0), width: 0.8),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Pesan Feedback
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: _feedbackList.length,
        ),
      ),
    );
  }
}
