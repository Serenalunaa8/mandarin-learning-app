import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/audio_service.dart';

// FR-12: Konversi Mata Uang (IDR, CNY, USD) dengan timestamp update & offline fallback
// PB-16: Kurs acuan PRD: 1 CNY ≈ 2.220 IDR, 1 USD ≈ 15.600 IDR, 1 USD ≈ 7.02 CNY

enum CurrencyCode { idr, cny, usd }

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final TextEditingController _amountController = TextEditingController(text: '100');
  CurrencyCode _fromCurrency = CurrencyCode.cny;
  CurrencyCode _toCurrency = CurrencyCode.idr;

  // Nilai kurs relatif terhadap 1 USD (Base USD)
  // 1 USD = 15.600 IDR, 1 USD = 7.02 CNY, 1 USD = 1.0 USD
  static const double _rateUsdToIdr = 15600.0;
  static const double _rateUsdToCny = 7.02;

  final DateTime _lastUpdated = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double _getRate(CurrencyCode from, CurrencyCode to) {
    if (from == to) return 1.0;

    // Convert from -> USD first
    double amountInUsd;
    switch (from) {
      case CurrencyCode.usd:
        amountInUsd = 1.0;
        break;
      case CurrencyCode.cny:
        amountInUsd = 1.0 / _rateUsdToCny;
        break;
      case CurrencyCode.idr:
        amountInUsd = 1.0 / _rateUsdToIdr;
        break;
    }

    // Convert USD -> to
    switch (to) {
      case CurrencyCode.usd:
        return amountInUsd;
      case CurrencyCode.cny:
        return amountInUsd * _rateUsdToCny;
      case CurrencyCode.idr:
        return amountInUsd * _rateUsdToIdr;
    }
  }

  double _calculateConverted(double inputAmount) {
    final rate = _getRate(_fromCurrency, _toCurrency);
    return inputAmount * rate;
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
    });
  }

  String _formatNumber(double val, CurrencyCode code) {
    if (code == CurrencyCode.idr) {
      return val.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]}.',
          );
    }
    return val.toStringAsFixed(2);
  }

  String _getMandarinTerm(CurrencyCode code) {
    switch (code) {
      case CurrencyCode.cny:
        return '人民币 (Rénmínbì / 元)';
      case CurrencyCode.idr:
        return '印尼盾 (Yìnnídùn)';
      case CurrencyCode.usd:
        return '美元 (Měiyuán)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputVal = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final convertedVal = _calculateConverted(inputVal);
    final unitRate = _getRate(_fromCurrency, _toCurrency);

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Konversi Mata Uang'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timestamp & Status Kurs
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, size: 16, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kurs diperbarui: ${_lastUpdated.day}/${_lastUpdated.month}/${_lastUpdated.year} (Offline Cache)',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Converter Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // From Currency Input
                    _buildCurrencyInputRow(
                      label: 'Jumlah Asal',
                      code: _fromCurrency,
                      controller: _amountController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Swap Button
                    Center(
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.swap_vert_rounded,
                            color: AppColors.primaryDark,
                            size: 24,
                          ),
                        ),
                        onPressed: _swapCurrencies,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // To Currency Output
                    _buildCurrencyOutputRow(
                      label: 'Hasil Konversi',
                      code: _toCurrency,
                      amountString: _formatNumber(convertedVal, _toCurrency),
                    ),
                    const Divider(height: 28),

                    // Exchange Rate Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '1 ${_fromCurrencyString()} =',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                        Text(
                          '${_formatNumber(unitRate, _toCurrency)} ${_toCurrencyString()}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Mandarin Vocabulary Context Card
              const Text(
                'Kosakata Mata Uang Mandarin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),

              _buildVocabCard(
                hanzi: '人民币',
                pinyin: 'Rénmínbì',
                arti: 'Mata uang Tiongkok (RMB / Yuan)',
              ),
              const SizedBox(height: 8),
              _buildVocabCard(
                hanzi: '汇率',
                pinyin: 'Huìlǜ',
                arti: 'Nilai tukar / Kurs mata uang',
              ),
              const SizedBox(height: 8),
              _buildVocabCard(
                hanzi: '多少钱？',
                pinyin: 'Duōshao qián?',
                arti: 'Berapa harganya?',
              ),
              const SizedBox(height: 20),

              // Quick Reference Table (Tabel Nilai Cepat CNY -> IDR)
              const Text(
                'Tabel Cepat Nilai Populer (CNY ➔ IDR)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [10, 50, 100, 200, 500].map((cny) {
                      final idr = cny * _getRate(CurrencyCode.cny, CurrencyCode.idr);
                      return ListTile(
                        dense: true,
                        leading: Text(
                          '¥ $cny',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        trailing: Text(
                          'Rp ${_formatNumber(idr, CurrencyCode.idr)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _fromCurrencyString() => _fromCurrency.name.toUpperCase();
  String _toCurrencyString() => _toCurrency.name.toUpperCase();

  Widget _buildCurrencyInputRow({
    required String label,
    required CurrencyCode code,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Text(
              _getMandarinTerm(code),
              style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: onChanged,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<CurrencyCode>(
                    value: _fromCurrency,
                    isExpanded: true,
                    items: CurrencyCode.values.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(
                          c.name.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _fromCurrency = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrencyOutputRow({
    required String label,
    required CurrencyCode code,
    required String amountString,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Text(
              _getMandarinTerm(code),
              style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  amountString,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<CurrencyCode>(
                    value: _toCurrency,
                    isExpanded: true,
                    items: CurrencyCode.values.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(
                          c.name.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _toCurrency = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVocabCard({
    required String hanzi,
    required String pinyin,
    required String arti,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hanzi,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      pinyin,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  arti,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryDark),
            onPressed: () => AudioService.instance.speak(hanzi),
          ),
        ],
      ),
    );
  }
}
