import '../auth/landing_screen.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/daily_goal_modal.dart';
import '../../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dailyReminderEnabled = true;
  int _reminderHour = 19;
  int _reminderMinute = 0;
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

  Future<void> _handleOverwriteBiometric(AuthProvider auth) async {
    final targetUser = auth.profile?.username ?? 'akun ini';
    final previousUser = auth.enrolledBiometricUsername ?? 'akun lain';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gantikan Pendaftaran Biometrik?'),
        content: Text(
          'Sensor biometrik di perangkat ini saat ini terhubung ke @$previousUser.\n\nSesuai standar keamanan 1-ke-1, mengaktifkan biometrik untuk @$targetUser akan menimpa dan menonaktifkan biometrik untuk @$previousUser.\n\nLanjutkan pemindaian biometrik untuk @$targetUser?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gantikan & Aktifkan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleEnrollBiometric(auth);
    }
  }

  Future<void> _toggleReminder(bool val) async {
    setState(() => _dailyReminderEnabled = val);
    if (val) {
      final permissionGranted = await NotificationService.instance
          .requestPermission();
      if (!permissionGranted) {
        await NotificationService.instance.cancelReminder();
        if (!mounted) return;
        setState(() => _dailyReminderEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izin notifikasi belum diberikan. Aktifkan notifikasi aplikasi di pengaturan perangkat.',
            ),
          ),
        );
        return;
      }
      try {
        await NotificationService.instance.scheduleDailyReminder(
          hour: _reminderHour,
          minute: _reminderMinute,
          requestPermissions: false,
        );
      } catch (error) {
        if (!mounted) return;
        setState(() => _dailyReminderEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pengingat gagal dijadwalkan: $error')),
        );
        return;
      }
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
        try {
          await NotificationService.instance.scheduleDailyReminder(
            hour: _reminderHour,
            minute: _reminderMinute,
            requestPermissions: true,
          );
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Pengingat gagal dijadwalkan: $error')),
            );
          }
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⏰ Pengingat harian disetel: Pukul  WIB (Notif masuk walau app ditutup).',
              ),
              backgroundColor: AppColors.primaryGreen,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _testNotificationIn5Seconds() async {
    try {
      await NotificationService.instance.scheduleNotificationInSeconds(
        seconds: 5,
        title: '⏰ Waktunya Belajar Mandarin!',
        body: 'Hebat! Pengingat belajar berhasil masuk meski aplikasi di luar/tertutup! 🎯',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notifikasi gagal dijadwalkan: $error')),
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🔔 Notifikasi dijadwalkan! Segera kunci layar atau keluar aplikasi untuk melihat notif masuk dalam 5 detik.',
          ),
          backgroundColor: AppColors.primaryGreen,
          duration: Duration(seconds: 4),
        ),
      );
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
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Section 1: Pembelajaran HSK
            const Text(
              'Pembelajaran',
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
                    subtitle: Text('HSK Level ${vocab.selectedLevel}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showLevelPicker(context, vocab, auth),
                  ),
                  const Divider(height: 1, indent: 64),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.timer_outlined,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    title: const Text(
                      'Target Waktu Belajar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text('${auth.dailyGoalMinutes} menit/hari'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showDailyGoalBottomSheet(context, auth),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Keamanan & Pendaftaran Biometrik
            const Text(
              'Keamanan & Biometrik',
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
                  // Status Pendaftaran Biometrik (1-ke-1 Single Account Binding & Guest Mode)
                  if (auth.isGuest) ...[
                    Container(
                      margin: const EdgeInsets.all(14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.no_accounts_rounded,
                                color: Color(0xFFB45309),
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Fitur Tidak Tersedia untuk Mode Tamu',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Pendaftaran biometrik dan penyimpanan preferensi akun hanya tersedia untuk akun terdaftar. Mode Tamu tidak menyimpan progres atau pengaturan apapun.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (!auth.isBiometricEnrolled) ...[
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
                            auth.isBiometricSupported
                                ? 'Daftarkan sensor sidik jari atau pengenalan wajah perangkat ini untuk akun @${auth.profile?.username ?? "Anda"}.'
                                : 'Pendaftaran biometrik membutuhkan aplikasi Android/iOS dan sensor yang sudah aktif; browser web tidak didukung.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF713F12),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                              label: Text(
                                'Daftarkan Biometrik (@${auth.profile?.username ?? "Akun Ini"})',
                                style: const TextStyle(
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
                  ] else if (!auth.isBiometricEnrolledForCurrentUser) ...[
                    // Kasus 1-to-1 Binding: Biometrik terikat ke akun lain
                    Container(
                      margin: const EdgeInsets.all(14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF97316)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.swap_horiz_rounded,
                                color: Color(0xFFC2410C),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Biometrik Terikat ke @${auth.enrolledBiometricUsername}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFFC2410C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sensor biometrik saat ini aktif untuk login akun @${auth.enrolledBiometricUsername}. Satu perangkat hanya dapat menautkan biometrik ke satu akun.\n\nJika diaktifkan untuk @${auth.profile?.username}, biometrik akun @${auth.enrolledBiometricUsername} akan ditimpa dan dinonaktifkan.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7C2D12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEA580C),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.published_with_changes_rounded,
                                size: 20,
                              ),
                              label: Text(
                                'Alihkan ke @${auth.profile?.username} (Gantikan)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              onPressed:
                                  auth.isLoading || !auth.isBiometricSupported
                                  ? null
                                  : () => _handleOverwriteBiometric(auth),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Terdaftar aktif untuk akun saat ini
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
                                const Text(
                                  'Biometrik Terdaftar Aktif',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                Text(
                                  'Akun: @${auth.profile?.username ?? "-"} • ${auth.biometricSensorLabel}',
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
                    subtitle: const Text('Tersimpan aman'),
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
              'Notifikasi',
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
                    subtitle: const Text('Jaga streak belajar'),
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
                    const Divider(height: 1),
                    ListTile(
                      leading: const SizedBox(width: 40),
                      title: const Text(
                        'Uji Notifikasi Luar Aplikasi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Kirim notif 5 detik lagi (bisa sambil tutup app)',
                        style: TextStyle(fontSize: 11),
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: _testNotificationIn5Seconds,
                        icon: const Icon(Icons.send_rounded, size: 14),
                        label: const Text(
                          'Tes (5s)',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF3C7),
                          foregroundColor: const Color(0xFFB45309),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 4: Izin Perangkat & Sensor (FR-04, FR-11)
            const Text(
              'Izin Perangkat',
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
                          ? 'Siap digunakan'
                          : 'Belum diizinkan',
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
                      'Untuk latihan pelafalan',
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

            // Tombol Keluar dari Akun
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _confirmLogout(context, auth),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar dari Akun'),
        content: const Text(
          'Apakah Anda yakin ingin keluar? Anda harus masuk kembali dengan kata sandi atau biometrik untuk mengakses aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Ya, Keluar'),
          ),
        ],
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
