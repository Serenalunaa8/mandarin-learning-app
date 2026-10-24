import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

/// Layanan notifikasi lokal & pengingat (flutter_local_notifications 22.x).
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
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (e) {
        debugPrint('[NotificationService] Gunakan default local timezone: $e');
      }

      const AndroidInitializationSettings initAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings =
          InitializationSettings(android: initAndroid);

      await _notificationsPlugin.initialize(
        settings: initSettings,
      );

      // Buat Notification Channels secara eksplisit agar Android OS tidak mendrop notif
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        const AndroidNotificationChannel dailyChannel = AndroidNotificationChannel(
          'mandarin_daily_reminders',
          'Pengingat Belajar Harian',
          description: 'Pengingat rutin untuk belajar kosakata Mandarin HSK',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        await androidPlugin.createNotificationChannel(dailyChannel);

        const AndroidNotificationChannel instantChannel = AndroidNotificationChannel(
          'mandarin_learning_reminders',
          'Pengingat Belajar',
          description: 'Pengingat rutin untuk belajar kosakata Mandarin HSK',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        await androidPlugin.createNotificationChannel(instantChannel);
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Notifikasi lokal berhasil diinisialisasi.');
    } catch (e) {
      debugPrint('[NotificationService] Gagal inisialisasi: $e');
    }
  }

  // ─── Izin ────────────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    try {
      if (!_isInitialized) await initialize();
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission();
      try {
        await androidImpl?.requestExactAlarmsPermission();
      } catch (_) {}
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
      'mandarin_daily_reminders',
      'Pengingat Belajar Harian',
      channelDescription: 'Pengingat harian untuk latihan kosakata & streak Mandarin',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  // ─── Kalkulasi Jadwal Waktu Berikutnya ────────────────────────────────────────

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
      0,
    );
    // Jika waktu sudah lewat hari ini, jadwalkan untuk besok di jam yang sama
    if (scheduledDate.isBefore(now.add(const Duration(seconds: 5)))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // ─── Jadwal Pengingat Harian (Out-of-App) ────────────────────────────────────

  Future<void> scheduleDailyReminder({int hour = 19, int minute = 0}) async {
    if (!_isInitialized) await initialize();
    await requestPermission();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', true);
    await prefs.setInt('reminder_hour', hour);
    await prefs.setInt('reminder_minute', minute);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'mandarin_daily_reminders',
      'Pengingat Belajar Harian',
      channelDescription: 'Pengingat harian untuk latihan kosakata & streak Mandarin',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final scheduled = _nextInstanceOfTime(hour, minute);

    try {
      await _notificationsPlugin.zonedSchedule(
        id: 1001,
        title: '⏰ Waktunya Belajar Mandarin!',
        body: 'Luangkan 5 menit hari ini untuk melatih kosakata HSK dan pertahankan streak belajarmu! 🚀',
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint(
          '[NotificationService] Pengingat harian dijadwalkan pada: $scheduled (WIB)');
    } catch (e) {
      debugPrint('[NotificationService] Fallback ke inexact schedule: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          id: 1001,
          title: '⏰ Waktunya Belajar Mandarin!',
          body: 'Luangkan 5 menit hari ini untuk melatih kosakata HSK dan pertahankan streak belajarmu! 🚀',
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e2) {
        debugPrint('[NotificationService] Gagal menjadwalkan notif harian: $e2');
      }
    }
  }

  // ─── Uji Notifikasi Keluar Aplikasi (Beberapa Detik ke Depan) ────────────────

  Future<void> scheduleNotificationInSeconds({
    int seconds = 5,
    String title = '⏰ Waktunya Belajar Mandarin!',
    String body = 'Hebat! Pengingat belajar berhasil masuk meski aplikasi di luar/tertutup! 🎯',
  }) async {
    if (!_isInitialized) await initialize();
    await requestPermission();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'mandarin_daily_reminders',
      'Pengingat Belajar Harian',
      channelDescription: 'Pengingat harian untuk latihan kosakata & streak Mandarin',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final scheduled =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

    try {
      await _notificationsPlugin.zonedSchedule(
        id: 1002,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint(
          '[NotificationService] Notifikasi uji dijadwalkan dalam $seconds detik: $scheduled');
    } catch (e) {
      debugPrint('[NotificationService] Uji fallback inexact: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          id: 1002,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e2) {
        debugPrint('[NotificationService] Uji fallback timer: $e2');
      }
    }
  }

  // ─── Batalkan Pengingat ───────────────────────────────────────────────────────

  Future<void> cancelReminder() async {
    if (!_isInitialized) await initialize();

    await _notificationsPlugin.cancel(id: 1001);
    await _notificationsPlugin.cancel(id: 1002);

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
