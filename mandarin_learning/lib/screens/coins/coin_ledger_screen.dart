import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/coin_transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../notifications/notification_history_screen.dart';

class CoinLedgerScreen extends StatelessWidget {
  const CoinLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final transactions = auth.coinTransactions;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF8F4),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFDDF5F5),
              Color(0xFFFFF7ED),
              Color(0xFFEAF1FB),
              Color(0xFFE8F6F0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, auth.coins),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _buildBalanceCard(auth.coins),
                    const SizedBox(height: 16),
                    _buildCoinHistory(transactions),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int balance) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Row(
        children: [
          _roundHeaderButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Saldo & Riwayat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF244E38),
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/image/beranda/koin.png',
                  width: 25,
                  height: 25,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 5),
                Text(
                  '$balance',
                  style: const TextStyle(
                    color: Color(0xFF244E38),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _roundHeaderButton(
            icon: Icons.notifications_none_rounded,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _roundHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.78),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF385D49), size: 22),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildBalanceCard(int balance) {
    return Container(
      height: 208,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD9A85F).withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.22,
            child: Image.asset(
              'assets/image/beranda/bg_siang.png',
              fit: BoxFit.cover,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xEFFFFFFF), Color(0x66FFF0CE)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Positioned(
            left: 22,
            top: 28,
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE9BC),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(9),
              child: Image.asset(
                'assets/image/beranda/koin.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            left: 96,
            top: 27,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo Koin',
                  style: TextStyle(
                    color: Color(0xFF37654B),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$balance',
                  style: const TextStyle(
                    color: Color(0xFF214C35),
                    fontSize: 44,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const Text(
                  'Koin tersedia',
                  style: TextStyle(
                    color: Color(0xFF789A89),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: -5,
            child: Image.asset(
              'assets/image/beranda/maskot_03_semangat.png',
              height: 162,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            right: 28,
            top: 49,
            child: Image.asset(
              'assets/image/beranda/kilau_01.png',
              width: 22,
              height: 22,
            ),
          ),
          Positioned(
            right: 143,
            bottom: 12,
            child: Image.asset(
              'assets/image/beranda/bunga_putih_2.png',
              width: 22,
              height: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinHistory(List<CoinTransaction> transactions) {
    if (transactions.isEmpty) {
      return _buildEmpty(
        icon: Icons.monetization_on_rounded,
        title: 'Belum ada transaksi koin',
        subtitle: 'Selesaikan kuis dan mini-game untuk mendapatkan koin!',
      );
    }

    return _buildHistoryCard(
      itemCount: transactions.length,
      itemBuilder: (index) => _buildTransactionTile(transactions[index]),
    );
  }

  Widget _buildHistoryCard({
    required int itemCount,
    required Widget Function(int index) itemBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3C8062).withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: itemCount,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: Color(0xFFEAF0F0), indent: 62),
        itemBuilder: (context, index) => itemBuilder(index),
      ),
    );
  }

  Widget _buildTransactionTile(CoinTransaction transaction) {
    final isEarn = transaction.amount > 0;
    final reason = '${transaction.transactionType} ${transaction.description}'
        .toLowerCase();
    final color = _transactionColor(reason, isEarn);

    return _historyRow(
      icon: _getIcon(reason),
      color: color,
      title: _getLabel(reason),
      subtitle: transaction.description,
      time: _formatDate(transaction.createdAt),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isEarn ? '+' : ''}${transaction.amount}',
            style: TextStyle(
              color: isEarn ? const Color(0xFF43B765) : const Color(0xFFE16C6C),
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(width: 4),
          Image.asset(
            'assets/image/beranda/koin.png',
            width: 21,
            height: 21,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _historyRow({
    required String icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 23)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF315440),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle.isEmpty ? 'Aktivitas belajar' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF879CAF),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF8A9DB0),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Color _transactionColor(String reason, bool isEarn) {
    if (!isEarn) return const Color(0xFFD77474);
    if (reason.contains('catcher')) return const Color(0xFFE6A64E);
    if (reason.contains('tilt')) return const Color(0xFF8E6AC1);
    if (reason.contains('speech') || reason.contains('pelafalan')) {
      return const Color(0xFF5E87D8);
    }
    if (reason.contains('hanzi_matching')) return const Color(0xFF4FAF81);
    return const Color(0xFFEF7772);
  }

  String _getIcon(String reason) {
    if (reason.contains('quiz') ||
        reason.contains('kuis') ||
        reason.contains('tebak_arti')) {
      return '🎯';
    }
    if (reason.contains('hanzi_matching')) return '🧩';
    if (reason.contains('streak')) return '🔥';
    if (reason.contains('hint') || reason.contains('bantuan')) return '💡';
    if (reason.contains('tilt')) return '📱';
    if (reason.contains('catcher')) return '🧺';
    if (reason.contains('stroke')) return '✍️';
    if (reason.contains('speech') || reason.contains('pelafalan')) return '🎙️';
    if (reason.contains('daily') || reason.contains('harian')) return '📅';
    return '🪙';
  }

  String _getLabel(String reason) {
    if (reason.contains('hanzi_matching_streak')) {
      return 'Bonus Streak Hanzi Matching';
    }
    if (reason.contains('hanzi_matching')) return 'Hanzi Matching';
    if (reason.contains('hint') || reason.contains('bantuan')) {
      return 'Penggunaan Bantuan';
    }
    if (reason.contains('tilt')) return 'Tilt to Answer';
    if (reason.contains('catcher')) return 'Mandarin Catcher';
    if (reason.contains('stroke')) return 'Stroke Challenge';
    if (reason.contains('speech') || reason.contains('pelafalan')) {
      return 'Pelafalan & Nada';
    }
    if (reason.contains('quiz') ||
        reason.contains('kuis') ||
        reason.contains('tebak_arti')) {
      return 'Kuis Tebak Arti';
    }
    if (reason.contains('daily') || reason.contains('harian')) {
      return 'Bonus Harian';
    }
    return reason.replaceAll('_', ' ').trim().toUpperCase();
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '—';
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inHours < 1) return '${difference.inMinutes} menit lalu';
    if (difference.inDays < 1) return '${difference.inHours} jam lalu';
    if (difference.inDays < 7) return '${difference.inDays} hari lalu';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 34),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFE5F5E9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF315440),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
