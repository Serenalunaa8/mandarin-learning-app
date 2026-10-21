import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../models/coin_transaction_model.dart';

// FR-20: Riwayat Koin — tampilkan saldo & ledger earn/spend, cegah duplikasi
class CoinLedgerScreen extends StatelessWidget {
  const CoinLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final balance = auth.coins;
    final transactions = auth.coinTransactions;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Saldo & Riwayat Koin'),
      ),
      body: Column(
        children: [
          _buildBalanceCard(balance),
          Expanded(
            child: transactions.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: transactions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _buildTransactionTile(transactions[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(int balance) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A5C), Color(0xFF2D5A8E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A3A5C).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Saldo Koin',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 8),
              Text(
                '$balance',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'koin tersisa',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(CoinTransaction tx) {
    final isEarn = tx.amount > 0;
    final reason = '${tx.transactionType} ${tx.description}'.toLowerCase();
    final icon = _getIcon(reason);
    final color = isEarn ? AppColors.primaryGreen : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getLabel(reason),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.description.isEmpty
                      ? _formatDate(tx.createdAt)
                      : '${tx.description} · ${_formatDate(tx.createdAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isEarn ? '+' : ''}${tx.amount} 🪙',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getIcon(String reason) {
    if (reason.contains('quiz') || reason.contains('kuis')) return '🎯';
    if (reason.contains('hanzi_matching')) return '🧩';
    if (reason.contains('streak')) return '🔥';
    if (reason.contains('hint') || reason.contains('bantuan')) return '💡';
    if (reason.contains('tilt')) return '📱';
    if (reason.contains('catcher')) return '🧺';
    if (reason.contains('stroke')) return '✍️';
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
    if (reason.contains('quiz') || reason.contains('kuis')) {
      return 'Kuis Tebak Arti';
    }
    if (reason.contains('daily')) return 'Bonus Harian';
    return reason.replaceAll('_', ' ').toUpperCase();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'Belum ada transaksi koin.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selesaikan kuis dan mini-game untuk mendapatkan koin!',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
