import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../services/notification_service.dart';

/// Komponen Notifikasi di Dalam Aplikasi (In-App Notification Banner).
/// Menampilkan banner mengambang (floating banner) dari atas layar
/// dengan animasi halus untuk reward kuis, pencapaian, dan koin.
class InAppNotification {
  static OverlayEntry? _currentEntry;

  /// Tampilkan notifikasi reward / kuis selesai
  static Future<void> showReward(
    BuildContext context, {
    required String title,
    required String message,
    int? score,
    int? coins,
  }) {
    return show(
      context,
      title: title,
      message: message,
      badgeText: coins != null && coins > 0 ? '+$coins 🪙' : null,
      icon: Icons.emoji_events_rounded,
      gradientColors: const [Color(0xFF065F46), Color(0xFF047857)],
      accentColor: const Color(0xFFFBBF24),
    );
  }

  /// Tampilkan notifikasi umum dalam aplikasi
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String? badgeText,
    IconData icon = Icons.notifications_active_rounded,
    List<Color>? gradientColors,
    Color accentColor = const Color(0xFFFBBF24),
    Duration duration = const Duration(milliseconds: 4000),
  }) async {
    // Haptic feedback saat notifikasi muncul
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    _currentEntry?.remove();
    _currentEntry = null;

    try {
      await NotificationService.instance.recordInAppNotification(
        title: title,
        body: message,
      );
    } catch (error) {
      debugPrint('[InAppNotification] Gagal menyimpan notifikasi: $error');
    }

    if (!context.mounted) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _InAppNotificationWidget(
        title: title,
        message: message,
        badgeText: badgeText,
        icon: icon,
        gradientColors:
            gradientColors ??
            const [AppColors.primaryDark, AppColors.primaryGreen],
        accentColor: accentColor,
        duration: duration,
        onDismiss: () {
          if (_currentEntry == entry) {
            entry.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _InAppNotificationWidget extends StatefulWidget {
  final String title;
  final String message;
  final String? badgeText;
  final IconData icon;
  final List<Color> gradientColors;
  final Color accentColor;
  final Duration duration;
  final VoidCallback onDismiss;

  const _InAppNotificationWidget({
    required this.title,
    required this.message,
    this.badgeText,
    required this.icon,
    required this.gradientColors,
    required this.accentColor,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_InAppNotificationWidget> createState() =>
      _InAppNotificationWidgetState();
}

class _InAppNotificationWidgetState extends State<_InAppNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    // Auto dismiss
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -4) {
                _dismiss();
              }
            },
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon container
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.accentColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Teks Notifikasi
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.badgeText != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    widget.badgeText!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 12,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Tombol Close kecil
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _dismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
