import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

/// Layanan notifikasi lokal (flutter_local_notifications 22.x).
/// Menggunakan named parameters sesuai API versi 22+.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // ─── Inisialisasi ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings =
          InitializationSettings(android: initAndroid);

      // flutter_local_notifications 22.x → named parameter `settings:`
      await _notificationsPlugin.initialize(
        settings: initSettings,
      );

      _isInitialized = true;
      debugPrint('[NotificationService] Notifikasi lokal berhasil diinisialisasi.');
    } catch (e) {
      debugPrint('[NotificationService] Gagal inisialisasi: $e');
    }
  }

  // ─── Izin ────────────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission();
      return granted ?? false;
    } catch (e) {
      debugPrint('[NotificationService] Error requestPermission: $e');
      return false;
    }
  }

  // ─── Tampilkan Notifikasi Langsung ───────────────────────────────────────────

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'mandarin_learning_reminders',
      'Pengingat Belajar',
      channelDescription: 'Pengingat rutin untuk belajar kosakata Mandarin HSK',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    // flutter_local_notifications 22.x → semua named parameters
    await _notificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  // ─── Jadwal Pengingat Harian ─────────────────────────────────────────────────

  Future<void> scheduleDailyReminder({int hour = 19, int minute = 0}) async {
    if (!_isInitialized) await initialize();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', true);
    await prefs.setInt('reminder_hour', hour);
    await prefs.setInt('reminder_minute', minute);

    debugPrint(
        '[NotificationService] Pengingat harian disimpan: pukul $hour:${minute.toString().padLeft(2, '0')} WIB.');
  }

  // ─── Batalkan Pengingat ───────────────────────────────────────────────────────

  Future<void> cancelReminder() async {
    if (!_isInitialized) await initialize();

    // flutter_local_notifications 22.x → named parameter `id:`
    await _notificationsPlugin.cancel(id: 1001);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', false);
    debugPrint('[NotificationService] Pengingat harian dimatikan.');
  }

  // ─── Cek Status Pengingat ─────────────────────────────────────────────────────

  Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('reminder_enabled') ?? true;
  }

  Future<int> getReminderHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('reminder_hour') ?? 19;
  }

  Future<int> getReminderMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('reminder_minute') ?? 0;
  }
}
