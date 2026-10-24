import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class AppNotificationEntry {
  final String id;
  final String title;
  final String body;
  final DateTime? receivedAt;
  final DateTime? scheduledAt;
  final bool isActive;

  const AppNotificationEntry({
    required this.id,
    required this.title,
    required this.body,
    this.receivedAt,
    this.scheduledAt,
    this.isActive = false,
  });

  factory AppNotificationEntry.fromJson(Map<String, dynamic> json) {
    return AppNotificationEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      receivedAt: DateTime.tryParse(json['received_at'] as String? ?? ''),
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'received_at': receivedAt?.toIso8601String(),
    'scheduled_at': scheduledAt?.toIso8601String(),
  };
}

/// Layanan notifikasi lokal & pengingat (flutter_local_notifications 22.x).
/// Menggunakan named parameters sesuai API versi 22+.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  static const _historyKey = 'app_notification_history';

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

      const InitializationSettings initSettings = InitializationSettings(
        android: initAndroid,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      // Buat Notification Channels secara eksplisit agar Android OS tidak mendrop notif
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        const AndroidNotificationChannel dailyChannel =
            AndroidNotificationChannel(
              'mandarin_daily_reminders',
              'Pengingat Belajar Harian',
              description:
                  'Pengingat rutin untuk belajar kosakata Mandarin HSK',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            );
        await androidPlugin.createNotificationChannel(dailyChannel);

        const AndroidNotificationChannel instantChannel =
            AndroidNotificationChannel(
              'mandarin_learning_reminders',
              'Pengingat Belajar',
              description:
                  'Pengingat rutin untuk belajar kosakata Mandarin HSK',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            );
        await androidPlugin.createNotificationChannel(instantChannel);
      }

      _isInitialized = true;
      final launchDetails = await _notificationsPlugin
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final response = launchDetails?.notificationResponse;
        if (response != null) _handleNotificationResponse(response);
      }
      debugPrint(
        '[NotificationService] Notifikasi lokal berhasil diinisialisasi.',
      );
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
            AndroidFlutterLocalNotificationsPlugin
          >();
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

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'mandarin_daily_reminders',
          'Pengingat Belajar Harian',
          channelDescription:
              'Pengingat harian untuk latihan kosakata & streak Mandarin',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final notificationId = 'instant-${DateTime.now().microsecondsSinceEpoch}';
    await recordInAppNotification(id: notificationId, title: title, body: body);
    await _notificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
      payload: _notificationPayload(title, body, notificationId),
    );
  }

  String _notificationPayload(String title, String body, String id) =>
      jsonEncode({'id': id, 'title': title, 'body': body});

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final title = data['title'] as String?;
      final body = data['body'] as String?;
      final id = data['id'] as String?;
      if (title == null || body == null) return;
      recordInAppNotification(id: id, title: title, body: body).catchError((
        Object error,
      ) {
        debugPrint(
          '[NotificationService] Gagal menyimpan notifikasi yang dibuka: $error',
        );
      });
    } on FormatException catch (error) {
      debugPrint(
        '[NotificationService] Payload notifikasi tidak valid: $error',
      );
    } on TypeError catch (error) {
      debugPrint(
        '[NotificationService] Format payload notifikasi tidak valid: $error',
      );
    }
  }

  Future<void> recordInAppNotification({
    String? id,
    required String title,
    required String body,
    DateTime? scheduledAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    final now = DateTime.now();
    final entryId = id ?? '${now.microsecondsSinceEpoch}';
    final entry = AppNotificationEntry(
      id: entryId,
      title: title,
      body: body,
      receivedAt: scheduledAt == null ? now : null,
      scheduledAt: scheduledAt,
    );
    history.removeWhere((value) {
      try {
        return (jsonDecode(value) as Map<String, dynamic>)['id'] == entryId;
      } on FormatException {
        return false;
      } on TypeError {
        return false;
      }
    });
    history.insert(0, jsonEncode(entry.toJson()));
    await prefs.setStringList(_historyKey, history);
  }

  Future<List<AppNotificationEntry>> getNotificationHistory() async {
    if (!_isInitialized) await initialize();

    final prefs = await SharedPreferences.getInstance();
    final history = <AppNotificationEntry>[];
    for (final value in prefs.getStringList(_historyKey) ?? const []) {
      try {
        final json = jsonDecode(value) as Map<String, dynamic>;
        history.add(AppNotificationEntry.fromJson(json));
      } on FormatException catch (error) {
        debugPrint(
          '[NotificationService] Riwayat notifikasi tidak valid: $error',
        );
      } on TypeError catch (error) {
        debugPrint(
          '[NotificationService] Format notifikasi tidak valid: $error',
        );
      }
    }

    try {
      final activeNotifications = await _notificationsPlugin
          .getActiveNotifications();
      final existingNotifications = history
          .map((entry) => '${entry.title}\u0000${entry.body}')
          .toSet();

      for (final notification in activeNotifications) {
        final title = notification.title ?? 'Notifikasi';
        final body = notification.body ?? '';
        final key = '$title\u0000$body';
        if (existingNotifications.add(key)) {
          history.add(
            AppNotificationEntry(
              id: 'active-${notification.id ?? key.hashCode}',
              title: title,
              body: body,
              isActive: true,
            ),
          );
        }
      }
    } on PlatformException catch (error) {
      debugPrint(
        '[NotificationService] Tidak dapat membaca notifikasi sistem aktif: $error',
      );
    } on MissingPluginException catch (error) {
      debugPrint(
        '[NotificationService] Riwayat sistem tidak tersedia di platform ini: $error',
      );
    }

    history.sort((a, b) {
      final aDate = a.receivedAt ?? a.scheduledAt;
      final bDate = b.receivedAt ?? b.scheduledAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return history;
  }

  Future<void> restoreDailyReminder() async {
    if (!_isInitialized) await initialize();

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('reminder_enabled') ?? true)) return;

    final permissionGranted = await requestPermission();
    if (!permissionGranted) {
      await prefs.setBool('reminder_enabled', false);
      debugPrint(
        '[NotificationService] Pengingat tidak dijadwalkan karena izin ditolak.',
      );
      return;
    }

    await scheduleDailyReminder(
      hour: prefs.getInt('reminder_hour') ?? 19,
      minute: prefs.getInt('reminder_minute') ?? 0,
      requestPermissions: false,
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

  Future<void> scheduleDailyReminder({
    int hour = 19,
    int minute = 0,
    bool requestPermissions = true,
  }) async {
    if (!_isInitialized) await initialize();
    if (requestPermissions && !await requestPermission()) {
      throw StateError('Izin notifikasi belum diberikan.');
    }

    final prefs = await SharedPreferences.getInstance();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'mandarin_daily_reminders',
          'Pengingat Belajar Harian',
          channelDescription:
              'Pengingat harian untuk latihan kosakata & streak Mandarin',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final scheduled = _nextInstanceOfTime(hour, minute);
    const notificationId = 'daily-reminder';
    const title = '⏰ Waktunya Belajar Mandarin!';
    const body =
        'Luangkan 5 menit hari ini untuk melatih kosakata HSK dan pertahankan streak belajarmu! 🚀';

    try {
      await _notificationsPlugin.zonedSchedule(
        id: 1001,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        payload: _notificationPayload(title, body, notificationId),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint(
        '[NotificationService] Pengingat harian dijadwalkan pada: $scheduled (WIB)',
      );
    } catch (e) {
      debugPrint('[NotificationService] Fallback ke inexact schedule: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          id: 1001,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: details,
          payload: _notificationPayload(title, body, notificationId),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e2) {
        debugPrint(
          '[NotificationService] Gagal menjadwalkan notif harian: $e2',
        );
        Error.throwWithStackTrace(e2, StackTrace.current);
      }
    }
    await recordInAppNotification(
      id: notificationId,
      title: title,
      body: body,
      scheduledAt: scheduled.toLocal(),
    );
    await prefs.setBool('reminder_enabled', true);
    await prefs.setInt('reminder_hour', hour);
    await prefs.setInt('reminder_minute', minute);
  }

  // ─── Uji Notifikasi Keluar Aplikasi (Beberapa Detik ke Depan) ────────────────

  Future<void> scheduleNotificationInSeconds({
    int seconds = 5,
    String title = '⏰ Waktunya Belajar Mandarin!',
    String body = 'Hebat! Pengingat belajar berhasil masuk meski aplikasi di luar/tertutup! 🎯',
  }) async {
    if (!_isInitialized) await initialize();
    if (!await requestPermission()) {
      throw StateError('Izin notifikasi belum diberikan.');
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'mandarin_daily_reminders',
          'Pengingat Belajar Harian',
          channelDescription:
              'Pengingat harian untuk latihan kosakata & streak Mandarin',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final scheduled = tz.TZDateTime.now(tz.local)
        .add(Duration(seconds: seconds));
    final notificationId = 'test-reminder-${scheduled.millisecondsSinceEpoch}';

    try {
      await _notificationsPlugin.zonedSchedule(
        id: 1002,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        payload: _notificationPayload(title, body, notificationId),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint(
        '[NotificationService] Notifikasi uji dijadwalkan dalam $seconds detik: $scheduled',
      );
    } catch (e) {
      debugPrint('[NotificationService] Uji fallback inexact: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          id: 1002,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: details,
          payload: _notificationPayload(title, body, notificationId),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e2) {
        debugPrint('[NotificationService] Uji fallback timer: $e2');
        Error.throwWithStackTrace(e2, StackTrace.current);
      }
    }
    await recordInAppNotification(
      id: notificationId,
      title: title,
      body: body,
      scheduledAt: scheduled.toLocal(),
    );
  }

  // ─── Batalkan Pengingat ───────────────────────────────────────────────────────

  Future<void> cancelReminder() async {
    if (!_isInitialized) await initialize();

    await _notificationsPlugin.cancel(id: 1001);
    await _notificationsPlugin.cancel(id: 1002);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', false);
    await _removeHistoryEntry('daily-reminder');
    await _removeHistoryEntries('test-reminder-');
    debugPrint('[NotificationService] Pengingat harian dimatikan.');
  }

  Future<void> _removeHistoryEntry(String id) =>
      _removeHistoryEntries(id, exactMatch: true);

  Future<void> _removeHistoryEntries(
    String id, {
    bool exactMatch = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    history.removeWhere((value) {
      try {
        final entryId = (jsonDecode(value) as Map<String, dynamic>)['id'];
        return exactMatch
            ? entryId == id
            : entryId is String && entryId.startsWith(id);
      } on FormatException {
        return false;
      } on TypeError {
        return false;
      }
    });
    await prefs.setStringList(_historyKey, history);
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
