import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/notification_service.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  late Future<List<AppNotificationEntry>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = NotificationService.instance.getNotificationHistory();
  }

  Future<void> _refresh() async {
    final notifications = NotificationService.instance.getNotificationHistory();
    setState(() => _notifications = notifications);
    await notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5F4EF),
        foregroundColor: const Color(0xFF315440),
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE5F5F5), Color(0xFFFFF8EE), Color(0xFFEEF2FB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<AppNotificationEntry>>(
          future: _notifications,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFD77474),
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Notifikasi belum dapat dimuat',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF315440),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(
                          () => _notifications = NotificationService.instance
                              .getNotificationHistory(),
                        ),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final notifications = snapshot.data ?? const [];
            if (notifications.isEmpty) {
              return _buildMessage(
                icon: Icons.notifications_none_rounded,
                title: 'Belum ada notifikasi',
                subtitle: 'Notifikasi pengingat dan hadiah belajar akan muncul di sini.',
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primaryDark,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      '${notifications.length} notifikasi',
                      style: const TextStyle(
                        color: Color(0xFF64806F),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ...List.generate(
                    notifications.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildNotificationCard(
                        notifications[index],
                        index,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotificationEntry notification, int index) {
    const colors = [
      Color(0xFFE8F5E9),
      Color(0xFFFFF1D8),
      Color(0xFFEAF1FC),
      Color(0xFFF2EAF8),
      Color(0xFFFFEDEE),
    ];
    final accent = colors[index % colors.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: accent),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF315440).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              notification.isActive
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_rounded,
              color: notification.isActive
                  ? const Color(0xFF42885B)
                  : const Color(0xFF617C9D),
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(
                    color: Color(0xFF315440),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      color: Color(0xFF687D8E),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  notification.receivedAt == null
                      ? 'Masih aktif di perangkat'
                      : _formatDate(notification.receivedAt!),
                  style: TextStyle(
                    color: notification.isActive
                        ? const Color(0xFF4D9862)
                        : const Color(0xFF91A0AC),
                    fontSize: 11,
                    fontWeight: notification.isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE1F1E5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF315440),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inHours < 1) return '${difference.inMinutes} menit lalu';
    if (difference.inDays < 1) return '${difference.inHours} jam lalu';
    if (difference.inDays < 7) return '${difference.inDays} hari lalu';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
