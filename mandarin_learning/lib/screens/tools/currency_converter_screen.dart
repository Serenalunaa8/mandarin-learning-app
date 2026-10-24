import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// FR-12 & PB-16: China Trip Budget Planner (旅行预算 · Lǚxíng yùsuàn) & Konversi 3 Mata Uang (IDR, CNY, USD)
// Kurs acuan resmi PRD: 1 CNY ≈ 2.220 IDR, 1 USD ≈ 15.600 IDR, 1 USD ≈ 7.02 CNY

enum CurrencyCode { idr, cny, usd }

enum TravelStyle { budget, standard, comfort }

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ─── Budget Planner State ──────────────────────────────────────────────────
  final TextEditingController _budgetController =
      TextEditingController(text: '2.000.000');
  TravelStyle _travelStyle = TravelStyle.standard;

  // ─── Quick Converter State ─────────────────────────────────────────────────
  final TextEditingController _amountController =
      TextEditingController(text: '100');
  CurrencyCode _fromCurrency = CurrencyCode.cny;
  CurrencyCode _toCurrency = CurrencyCode.idr;

  // Nilai kurs relatif terhadap 1 USD (Base USD)
  static const double _rateUsdToIdr = 15600.0;
  static const double _rateUsdToCny = 7.02;

  final DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _budgetController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ─── Kalkulasi Kurs ────────────────────────────────────────────────────────

  double _getRate(CurrencyCode from, CurrencyCode to) {
    if (from == to) return 1.0;

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

  String _formatIdrOnly(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
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

  double _parseBudgetIdr() {
    final clean = _budgetController.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('Rp', '')
        .replaceAll(' ', '')
        .trim();
    return double.tryParse(clean) ?? 0.0;
  }

  // ─── Build UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('China Trip Budget Planner'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGreen,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.flight_takeoff_rounded, size: 20),
              text: 'Perencana Anggaran',
            ),
            Tab(
              icon: Icon(Icons.currency_exchange_rounded, size: 20),
              text: 'Kalkulator Kurs Bebas',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTripBudgetPlannerTab(),
            _buildQuickConverterTab(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 1: CHINA TRIP BUDGET PLANNER (旅行预算)
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildTripBudgetPlannerTab() {
    final budgetIdr = _parseBudgetIdr();
    final rateIdrToCny = _getRate(CurrencyCode.idr, CurrencyCode.cny);
    final rateIdrToUsd = _getRate(CurrencyCode.idr, CurrencyCode.usd);
    final totalCny = budgetIdr * rateIdrToCny;
    final totalUsd = budgetIdr * rateIdrToUsd;

    // Alokasi kategori berdasarkan gaya perjalanan
    double pctTransport = 0.25;
    double pctHotel = 0.35;
    double pctFood = 0.25;
    double pctActivity = 0.15;

    if (_travelStyle == TravelStyle.budget) {
      pctTransport = 0.20;
      pctHotel = 0.25;
      pctFood = 0.30;
      pctActivity = 0.25;
    } else if (_travelStyle == TravelStyle.comfort) {
      pctTransport = 0.20;
      pctHotel = 0.45;
      pctFood = 0.20;
      pctActivity = 0.15;
    }

    final idrTransport = budgetIdr * pctTransport;
    final cnyTransport = totalCny * pctTransport;

    final idrHotel = budgetIdr * pctHotel;
    final cnyHotel = totalCny * pctHotel;

    final idrFood = budgetIdr * pctFood;
    final cnyFood = totalCny * pctFood;

    final idrActivity = budgetIdr * pctActivity;
    final cnyActivity = totalCny * pctActivity;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Konsep Fitur Sesuai Panduan PRD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('🇨🇳', style: TextStyle(fontSize: 30)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'China Trip Budget Planner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '旅行预算 · Lǚxíng yùsuàn',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rencanakan anggaran perjalanan ke Tiongkok. Masukkan anggaran dalam Rupiah, sistem memperkirakan Yuan yang tersedia dan membagi kebutuhan transportasi, makanan, penginapan, dan aktivitas secara cerdas.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Input Anggaran Perjalanan dalam Rupiah
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Masukkan Anggaran Perjalanan (Rp)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '印尼盾 (IDR)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // TextField Input
                TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setState(() {});
                  },
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                    hintText: 'Contoh: 2.000.000',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primaryGreen, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Preset Chips (Termasuk Contoh Rp 2.000.000 dari Soal)
                const Text(
                  'Preset Anggaran Cepat:',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildBudgetPresetChip('Rp 2.000.000 (Contoh)', '2.000.000'),
                      _buildBudgetPresetChip('Rp 5.000.000', '5.000.000'),
                      _buildBudgetPresetChip('Rp 10.000.000', '10.000.000'),
                      _buildBudgetPresetChip('Rp 20.000.000', '20.000.000'),
                    ],
                  ),
                ),
                const Divider(height: 24),

                // Live Converted Summary (Total Yuan & Total USD)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text('💴 ', style: TextStyle(fontSize: 14)),
                                Text(
                                  'Perkiraan Yuan (CNY)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '¥ ${_formatNumber(totalCny, CurrencyCode.cny)}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const Text(
                              '人民币 (Rénmínbì)',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text('💵 ', style: TextStyle(fontSize: 14)),
                                Text(
                                  'Perkiraan Dolar (USD)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1E40AF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$ ${_formatNumber(totalUsd, CurrencyCode.usd)}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            const Text(
                              '美元 (Měiyuán)',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Kurs acuan: 1 CNY ≈ Rp 2.220 IDR | 1 USD ≈ Rp 15.600 IDR (${_lastUpdated.day}/${_lastUpdated.month}/${_lastUpdated.year})',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Pilihan Gaya Perjalanan (Travel Style Presets)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gaya Alokasi Perjalanan:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '${(pctTransport * 100).toInt()}% • ${(pctHotel * 100).toInt()}% • ${(pctFood * 100).toInt()}% • ${(pctActivity * 100).toInt()}%',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStyleChip(
                label: '⚖️ Standar (Seimbang)',
                style: TravelStyle.standard,
              ),
              const SizedBox(width: 8),
              _buildStyleChip(
                label: '🎒 Backpacker (Hemat)',
                style: TravelStyle.budget,
              ),
              const SizedBox(width: 8),
              _buildStyleChip(
                label: '⭐ Nyaman (Hotel+)',
                style: TravelStyle.comfort,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ─── 4 KATEGORI UTAMA PERENCANAAN PERJALANAN ──────────────────────────
          const Text(
            'Pembagian Anggaran Kebutuhan Perjalanan:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),

          // 1. Transportasi (交通 · Jiāotōng)
          _buildCategoryCard(
            titleId: 'Transportasi',
            titleZh: '交通 · Jiāotōng',
            emoji: '🚆',
            percentage: (pctTransport * 100).toInt(),
            idrAmount: idrTransport,
            cnyAmount: cnyTransport,
            colorAccent: const Color(0xFF0284C7),
            bgAccent: const Color(0xFFF0F9FF),
            estimates: const [
              'Tiket Metro/Subway (地铁): ¥3 - ¥8 per perjalanan',
              'Tiket Kereta Cepat (高铁): ¥300 - ¥550 (antar kota)',
              'Taksi / Didi (出租车): ¥15 - ¥40 (dalam kota)',
            ],
            phrases: const [
              '买一张去北京的高铁票 (Beli 1 tiket kereta cepat ke Beijing)',
              '请问地铁站在哪里？ (Di mana stasiun subway?)',
            ],
          ),
          const SizedBox(height: 12),

          // 2. Penginapan (住宿 · Zhùsù)
          _buildCategoryCard(
            titleId: 'Penginapan & Hotel',
            titleZh: '住宿 · Zhùsù',
            emoji: '🏨',
            percentage: (pctHotel * 100).toInt(),
            idrAmount: idrHotel,
            cnyAmount: cnyHotel,
            colorAccent: const Color(0xFF7C3AED),
            bgAccent: const Color(0xFFF5F3FF),
            estimates: const [
              'Hostel / Budget Hotel (快捷酒店): ¥120 - ¥250 / malam',
              'Hotel Berbintang (星级酒店): ¥350 - ¥650 / malam',
              'Deposit kamar (押金): rata-rata ¥100 - ¥200',
            ],
            phrases: const [
              '我要办理入住 (Saya ingin proses check-in)',
              '包含早餐吗？ (Apakah termasuk sarapan?)',
            ],
          ),
          const SizedBox(height: 12),

          // 3. Makanan & Minuman (餐饮 · Cānyǐn)
          _buildCategoryCard(
            titleId: 'Makanan & Kuliner',
            titleZh: '餐饮 · Cānyǐn',
            emoji: '🍜',
            percentage: (pctFood * 100).toInt(),
            idrAmount: idrFood,
            cnyAmount: cnyFood,
            colorAccent: const Color(0xFFD97706),
            bgAccent: const Color(0xFFFFFBEB),
            estimates: const [
              'Street Food & Mie Tarik (拉面/小吃): ¥15 - ¥30',
              'Restoran Lokal / Hotpot (中餐/火锅): ¥60 - ¥120 / orang',
              'Kopi & Teh Susu (奶茶/咖啡): ¥15 - ¥25',
            ],
            phrases: const [
              '服务员，买单！ (Pelayan, tolong tagihannya!)',
              '不要太辣 (Tolong jangan terlalu pedas)',
            ],
          ),
          const SizedBox(height: 12),

          // 4. Aktivitas & Wisata (活动与门票 · Huódòng yǔ Ménpiào)
          _buildCategoryCard(
            titleId: 'Aktivitas & Tiket Wisata',
            titleZh: '活动与门票 · Huódòng',
            emoji: '🎟️',
            percentage: (pctActivity * 100).toInt(),
            idrAmount: idrActivity,
            cnyAmount: cnyActivity,
            colorAccent: const Color(0xFF059669),
            bgAccent: const Color(0xFFECFDF5),
            estimates: const [
              'Tiket Kota Terlarang (故宫门票): ~¥40 - ¥60',
              'Tiket Tembok Besar Mutianyu (长城门票): ~¥45',
              'Belanja Suvenir & Oleh-oleh (纪念品): ¥50 - ¥150',
            ],
            phrases: const [
              '一张成人票 (Satu tiket untuk dewasa)',
              '可以便宜一点吗？ (Bisa lebih murah sedikit?)',
            ],
          ),
          const SizedBox(height: 18),

          // Tips Pembayaran di Tiongkok
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded,
                        color: Color(0xFFF59E0B), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Tips Pembayaran & Transaksi di Tiongkok',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Hampir semua transaksi di Tiongkok menggunakan QR Code via Alipay (支付宝) atau WeChat Pay (微信支付).\n'
                  '• Turis asing kini bisa menghubungkan kartu kredit/debit Visa & Mastercard langsung ke aplikasi Alipay tanpa perlu rekening bank Tiongkok.\n'
                  '• Selalu sediakan sedikit uang tunai pecahan kecil (零钱 Língqián) untuk keadaan darurat.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey[700],
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBudgetPresetChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        onPressed: () {
          setState(() {
            _budgetController.text = value;
          });
        },
      ),
    );
  }

  Widget _buildStyleChip({required String label, required TravelStyle style}) {
    final isSelected = _travelStyle == style;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _travelStyle = style;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryGreen
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String titleId,
    required String titleZh,
    required String emoji,
    required int percentage,
    required double idrAmount,
    required double cnyAmount,
    required Color colorAccent,
    required Color bgAccent,
    required List<String> estimates,
    required List<String> phrases,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgAccent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
        title: Row(
          children: [
            Text(
              titleId,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: bgAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorAccent,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          titleZh,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textMuted,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Jumlah Anggaran (IDR & CNY)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alokasi Rupiah:',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      Text(
                        'Rp ${_formatIdrOnly(idrAmount)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colorAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: colorAccent.withOpacity(0.3),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Perkiraan Yuan:',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      Text(
                        '¥ ${_formatNumber(cnyAmount, CurrencyCode.cny)} 元',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Estimasi Biaya Nyata di Tiongkok
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Estimasi Biaya Acuan di China:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ...estimates.map((est) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colorAccent)),
                    Expanded(
                      child: Text(
                        est,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey[800],
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),

          // Frasa Mandarin Terkait
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🗣️ Frasa Mandarin yang Sering Digunakan:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                ...phrases.map((ph) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '› $ph',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 2: KALKULATOR KURS BEBAS (3 MATA UANG: CNY, IDR, USD)
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildQuickConverterTab() {
    final inputVal =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final convertedVal = _calculateConverted(inputVal);
    final unitRate = _getRate(_fromCurrency, _toCurrency);

    return SingleChildScrollView(
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
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_rounded,
                    size: 16, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kurs diperbarui: ${_lastUpdated.day}/${_lastUpdated.month}/${_lastUpdated.year} (Offline Cache)',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                  color: Colors.black.withOpacity(0.04),
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
                      decoration: const BoxDecoration(
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
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted),
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

          // Preset Biaya Nyata Tempat (Toko Baju, Hotel, Resto/Kafe)
          const Text(
            'Preset Biaya Tempat Nyata di China',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetCategoryChip('👗 Kemeja Baju ¥120', 120),
                _buildPresetCategoryChip('👗 Gaun / Dress ¥180', 180),
                _buildPresetCategoryChip('👗 Jaket Tren ¥250', 250),
                _buildPresetCategoryChip('🏨 Hotel Standar ¥220', 220),
                _buildPresetCategoryChip('🏨 Hotel Deluxe ¥350', 350),
                _buildPresetCategoryChip('☕ Kopi / Teh ¥25', 25),
                _buildPresetCategoryChip('🍜 Makanan Khas ¥38', 38),
                _buildPresetCategoryChip('🍲 Paket Makan Berdua ¥85', 85),
              ],
            ),
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
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [10, 50, 100, 200, 500].map((cny) {
                  final idr =
                      cny * _getRate(CurrencyCode.cny, CurrencyCode.idr);
                  return ListTile(
                    dense: true,
                    leading: Text(
                      '¥ $cny',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark),
                    ),
                    trailing: Text(
                      'Rp ${_formatNumber(idr, CurrencyCode.idr)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPresetCategoryChip(String label, double cnyAmount) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        onPressed: () {
          setState(() {
            _fromCurrency = CurrencyCode.cny;
            _amountController.text = cnyAmount.toStringAsFixed(0);
          });
        },
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
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Text(
              _getMandarinTerm(code),
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold),
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: onChanged,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Text(
              _getMandarinTerm(code),
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
}
