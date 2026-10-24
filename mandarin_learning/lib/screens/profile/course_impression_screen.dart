import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/avatar_image_helper.dart';

class CourseImpressionScreen extends StatefulWidget {
  const CourseImpressionScreen({super.key});

  @override
  State<CourseImpressionScreen> createState() => _CourseImpressionScreenState();
}

class _CourseImpressionScreenState extends State<CourseImpressionScreen> {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingList = true;
  List<Map<String, dynamic>> _impressions = [];

  @override
  void initState() {
    super.initState();
    _loadImpressions();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadImpressions() async {
    setState(() {
      _isLoadingList = true;
    });

    final data = await SupabaseService.instance.fetchCourseImpressions();

    if (mounted) {
      setState(() {
        _impressions = data;
        _isLoadingList = false;
      });
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
    return auth.isGuest ? 'Tamu' : 'Pengguna';
  }

  void _handleSubmit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan ketik kesan & pesan terlebih dahulu.'),
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

    final success = await SupabaseService.instance.submitCourseImpression(
      userId: userId,
      accountName: accountName,
      message: message,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (!mounted) return;

    if (success) {
      _messageController.clear();
      FocusScope.of(context).unfocus();

      // Tambahkan item secara langsung di urutan teratas agar responsif
      setState(() {
        _impressions.insert(0, {
          'account_name': accountName,
          'message': message,
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      ScesanSnackBar('Kesan & pesan berhasil dikirim dan ditampilkan!');
      _loadImpressions();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengirim kesan & pesan. Periksa koneksi atau pastikan tabel di Supabase sudah siap.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void ScesanSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Baru saja';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit yang lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam yang lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari yang lalu';

      final day = dt.day.toString().padLeft(2, '0');
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final month = months[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$minute';
    } catch (_) {
      return 'Baru saja';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final accountName = _getAccountName(auth);
    final avatarUrl = auth.profile?.avatarUrl ?? '';

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Kesan & Pesan Matkul Mobile'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan data',
            onPressed: _loadImpressions,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadImpressions,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Bagian Atas: Input Form Kesan & Pesan
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A24).withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Identitas Akun Pengirim
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFDCFCE7),
                              ),
                              child: ClipOval(
                                child: avatarUrl.isNotEmpty
                                    ? buildUserAvatarWidget(avatarUrl, width: 38, height: 38, fit: BoxFit.cover)
                                    : Center(
                                        child: Text(
                                          accountName.isNotEmpty ? accountName[0].toUpperCase() : '👤',
                                          style: const TextStyle(
                                            color: Color(0xFF16A34A),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          accountName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Akun Anda',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Mata Kuliah Pemrograman Aplikasi Mobile',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Input Box Kesan & Pesan
                        TextField(
                          controller: _messageController,
                          maxLines: 4,
                          minLines: 3,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Ketik kesan & pesanmu untuk mata kuliah Pemrograman Aplikasi Mobile di sini...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Tombol Kirim
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isSubmitting ? null : _handleSubmit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send_rounded, size: 16, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Kirim Kesan & Pesan',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Judul Daftar di Bawahnya
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Row(
                    children: [
                      const Text(
                        'Daftar Kesan & Pesan',
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
                          '${_impressions.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Daftar Pesan yang Langsung Tampil di Bawahnya
              if (_isLoadingList)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                )
              else if (_impressions.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('📝', style: TextStyle(fontSize: 28)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Belum ada kesan & pesan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Jadilah yang pertama menuliskan kesan & pesan perkuliahan mobile di atas!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _impressions[index];
                        final name = (item['account_name'] ?? item['student_name'] ?? 'Mahasiswa').toString();
                        final msg = (item['message'] ?? item['kesan'] ?? '').toString();
                        final dateStr = _formatTimestamp(item['created_at']?.toString());
                        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Kartu: Nama Akun & Waktu
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
                                          name,
                                          style: const TextStyle(
                                            fontSize: 14,
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
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Isi Kesan & Pesan
                              Text(
                                msg,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF334155),
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: _impressions.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
