import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dailyReminderEnabled = true;
  int _reminderHour = 19;
  int _reminderMinute = 0;
  bool? _isCloudConnected;

  LocationPermission _locationStatus = LocationPermission.denied;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await NotificationService.instance.isReminderEnabled();
    final hour = await NotificationService.instance.getReminderHour();
    final minute = await NotificationService.instance.getReminderMinute();

    LocationPermission locStatus = LocationPermission.denied;
    try {
      locStatus = await Geolocator.checkPermission();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _dailyReminderEnabled = enabled;
        _reminderHour = hour;
        _reminderMinute = minute;
        _locationStatus = locStatus;
      });
    }

    final cloudConnected = await SupabaseService.instance.checkConnection();
    if (mounted) {
      setState(() => _isCloudConnected = cloudConnected == true);
    }
  }

  Future<void> _handleEnrollBiometric(AuthProvider auth) async {
    final success = await auth.enrollBiometric();
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Biometrik (Sidik Jari & Wajah) berhasil didaftarkan untuk akun ini!',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleUnenrollBiometric(AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pendaftaran Biometrik?'),
        content: const Text(
          'Akun Anda tidak akan dapat masuk menggunakan sensor sidik jari atau pengenalan wajah sampai didaftarkan kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Pendaftaran'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await auth.unenrollBiometric();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pendaftaran biometrik berhasil dihapus.'),
        ),
      );
    }
  }

  Future<void> _toggleReminder(bool val) async {
    setState(() => _dailyReminderEnabled = val);
    if (val) {
      await NotificationService.instance.requestPermission();
      await NotificationService.instance.scheduleDailyReminder(
        hour: _reminderHour,
        minute: _reminderMinute,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pengingat harian aktif: Pukul ${_formatTime(_reminderHour, _reminderMinute)} WIB',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } else {
      await NotificationService.instance.cancelReminder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengingat harian dinonaktifkan.')),
        );
      }
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked != null) {
      setState(() {
        _reminderHour = picked.hour;
        _reminderMinute = picked.minute;
      });
      if (_dailyReminderEnabled) {
        await NotificationService.instance.scheduleDailyReminder(
          hour: _reminderHour,
          minute: _reminderMinute,
        );
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    final res = await Geolocator.requestPermission();
    setState(() => _locationStatus = res);
  }

  String _formatTime(int h, int m) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vocab = context.watch<VocabularyProvider>();

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('Pengaturan Aplikasi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Section 1: Pembelajaran HSK
            const Text(
              'Target Pembelajaran',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),

            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    title: const Text(
                      'Tingkat HSK Aktif',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Sedang fokus di HSK Level ${vocab.selectedLevel}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showLevelPicker(context, vocab, auth),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Keamanan & Pendaftaran Biometrik
            const Text(
              'Keamanan & Pendaftaran Biometrik',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),

            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Status Pendaftaran Biometrik
                  if (!auth.isBiometricEnrolled) ...[
                    Container(
                      margin: const EdgeInsets.all(14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF9C3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFACC15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.fingerprint_rounded,
                                color: Color(0xFF854D0E),
                                size: 24,
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.face_retouching_natural_rounded,
                                color: Color(0xFF854D0E),
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Biometrik Belum Didaftarkan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF854D0E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            auth.isGuest
                                ? 'Masuk dengan akun terdaftar untuk mengaktifkan pendaftaran biometrik.'
                                : auth.isBiometricSupported
                                ? 'Daftarkan sensor yang sudah aktif di perangkat agar bisa login tanpa mengetik kata sandi.'
                                : 'Pendaftaran biometrik membutuhkan aplikasi Android/iOS dan sensor yang sudah aktif; browser web tidak didukung.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF713F12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!auth.isGuest)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.security_rounded,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Daftarkan Sidik Jari & Wajah',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed:
                                    auth.isLoading || !auth.isBiometricSupported
                                    ? null
                                    : () => _handleEnrollBiometric(auth),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Jika sudah terdaftar: Tampilkan status sukses dan kontrol sensor
                    Container(
                      margin: const EdgeInsets.all(14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            color: AppColors.primaryGreen,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Biometrik Terdaftar Aktif',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                Text(
                                  'Akun: @${auth.enrolledBiometricUsername ?? auth.profile?.username ?? "-"} • ${auth.biometricSensorLabel}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Toggle Penggunaan Sidik Jari
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      title: const Text(
                        'Sensor Sidik Jari',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        auth.hasFingerprintSensor
                            ? 'Gunakan sidik jari untuk verifikasi masuk'
                            : 'Sidik jari belum terdaftar di perangkat',
                      ),
                      value:
                          auth.hasFingerprintSensor &&
                          auth.isFingerprintAllowed,
                      activeTrackColor: AppColors.primaryGreen,
                      onChanged: auth.hasFingerprintSensor
                          ? (val) => auth.setBiometricSensorPreference(
                              fingerprint: val,
                            )
                          : null,
                    ),
                    const Divider(height: 1),

                    // Toggle Penggunaan Pengenalan Wajah
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.face_retouching_natural_rounded,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                      title: const Text(
                        'Pengenalan Wajah (Face)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        auth.hasFaceSensor
                            ? 'Gunakan pemindaian wajah untuk verifikasi masuk'
                            : 'Pengenalan wajah belum terdaftar di perangkat',
                      ),
                      value: auth.hasFaceSensor && auth.isFaceAllowed,
                      activeTrackColor: AppColors.primaryGreen,
                      onChanged: auth.hasFaceSensor
                          ? (val) =>
                                auth.setBiometricSensorPreference(face: val)
                          : null,
                    ),
                    const Divider(height: 1),

                    // Tombol Hapus / Daftarkan Ulang
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                      ),
                      title: const Text(
                        'Hapus Pendaftaran Biometrik',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                      subtitle: const Text(
                        'Hapus keterkaitan sidik jari dan wajah dari perangkat ini',
                        style: TextStyle(fontSize: 11),
                      ),
                      onTap: auth.isLoading
                          ? null
                          : () => _handleUnenrollBiometric(auth),
                    ),
                  ],

                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFF475569),
                      ),
                    ),
                    title: const Text(
                      'Enkripsi Kredensial',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Password dienkripsi SHA-256 tanpa Firebase (Tersimpan aman di DB)',
                    ),
                    trailing: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 3: Notifikasi & Jadwal Pengingat (FR-16)
            const Text(
              'Notifikasi & Jadwal Pengingat (FR-16)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),

            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    title: const Text(
                      'Pengingat Belajar Harian',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Kirim notifikasi untuk menjaga streak belajar',
                    ),
                    value: _dailyReminderEnabled,
                    activeTrackColor: AppColors.primaryGreen,
                    onChanged: _toggleReminder,
                  ),
                  if (_dailyReminderEnabled) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const SizedBox(width: 40),
                      title: const Text(
                        'Waktu Pengingat',
                        style: TextStyle(fontSize: 13),
                      ),
                      trailing: Text(
                        '${_formatTime(_reminderHour, _reminderMinute)} WIB',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                          fontSize: 14,
                        ),
                      ),
                      onTap: _pickReminderTime,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 4: Izin Perangkat & Sensor (FR-04, FR-11)
            const Text(
              'Izin Perangkat & Sensor (FR-04, FR-11)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),

            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    title: const Text(
                      'Izin Lokasi (GPS)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      _locationStatus == LocationPermission.always ||
                              _locationStatus == LocationPermission.whileInUse
                          ? 'Diizinkan (Siap untuk Direction Explorer)'
                          : 'Belum diizinkan / Ditolak',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing:
                        _locationStatus == LocationPermission.always ||
                            _locationStatus == LocationPermission.whileInUse
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primaryGreen,
                          )
                        : TextButton(
                            onPressed: _requestLocationPermission,
                            child: const Text('Izinkan'),
                          ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    title: const Text(
                      'Izin Mikrofon',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Diperlukan untuk Latihan Pelafalan & Analisis Nada',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 5: Akun & Status Penyimpanan
            const Text(
              'Status Penyimpanan (Lokal & Online)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isCloudConnected == null
                            ? Icons.cloud_sync_rounded
                            : _isCloudConnected!
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        color: _isCloudConnected == null
                            ? AppColors.textMuted
                            : _isCloudConnected!
                            ? AppColors.primaryGreen
                            : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isCloudConnected == null
                            ? 'Memeriksa koneksi Supabase...'
                            : _isCloudConnected!
                            ? 'Supabase dapat dijangkau'
                            : 'Supabase tidak dapat dijangkau',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    auth.isGuest
                        ? 'Mode tamu: progres dan koin hanya disimpan di perangkat dan tidak disinkronkan ke akun cloud.'
                        : 'Username: ${auth.profile?.username.isNotEmpty == true ? auth.profile!.username : (auth.profile?.fullName ?? "-")}\nDatabase lokal: SQLite\nSupabase: ${_isCloudConnected == null
                              ? "sedang diperiksa"
                              : _isCloudConnected!
                              ? "dapat dijangkau"
                              : "tidak dapat dijangkau"}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  void _showLevelPicker(
    BuildContext context,
    VocabularyProvider vocab,
    AuthProvider auth,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Pilih Target Level HSK'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(6, (idx) {
            final lvl = idx + 1;
            return ListTile(
              title: Text('HSK Level $lvl'),
              selected: vocab.selectedLevel == lvl,
              trailing: vocab.selectedLevel == lvl
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                    )
                  : null,
              onTap: () {
                vocab.setLevel(lvl);
                auth.setHskLevel(lvl);
                Navigator.pop(ctx);
              },
            );
          }),
        ),
      ),
    );
  }
}
