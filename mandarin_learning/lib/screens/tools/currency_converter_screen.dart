import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

// FR-12 & PB-16: China Trip Budget Planner (旅行预算 · Lǚxíng yùsuàn) & Konversi 3 Mata Uang (IDR, CNY, USD)
// Kurs acuan mid-market: 1 CNY ≈ 2.721 IDR, 1 USD ≈ 18.144 IDR, 1 USD ≈ 6.667 CNY.

enum CurrencyCode { idr, cny, usd }

class _TripOption {
  final String label;
  final String detail;
  final double priceCny;

  const _TripOption(this.label, this.detail, this.priceCny);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TripOption &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          priceCny == other.priceCny;

  @override
  int get hashCode => Object.hash(label, priceCny);
}

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ─── Budget Planner State ──────────────────────────────────────────────────
  final TextEditingController _budgetController = TextEditingController(
    text: '8.000.000',
  );
  final TextEditingController _destinationController = TextEditingController(
    text: 'Shanghai',
  );
  static const List<_TripOption> _transportOptions = [
    _TripOption('Metro + bus', 'Beijing · sekitar ¥25/orang/hari', 25),
    _TripOption(
      'Metro + sesekali DiDi',
      'Beijing · sekitar ¥70/orang/hari',
      70,
    ),
    _TripOption(
      'DiDi/taksi lebih sering',
      'Beijing · sekitar ¥180/orang/hari',
      180,
    ),
  ];
  static const List<_TripOption> _hotelOptions = [
    _TripOption('Hostel (ranjang dorm)', 'Per orang · ¥120/malam', 120),
    _TripOption('Hotel budget', 'Kamar sederhana · ¥300/kamar/malam', 300),
    _TripOption('Hotel kelas menengah', 'Kamar · ¥600/kamar/malam', 600),
  ];
  static const List<_TripOption> _foodOptions = [
    _TripOption('Hemat (jajanan/lokal)', '¥50/orang/hari', 50),
    _TripOption('Kuliner lokal', 'Warung/restoran lokal · ¥90/orang/hari', 90),
    _TripOption('Restoran nyaman', '¥180/orang/hari', 180),
  ];
  static const List<_TripOption> _activityOptions = [
    _TripOption(
      'Gratis + taman kota',
      'Contoh: Tiananmen area (reservasi), taman gratis · ¥0',
      0,
    ),
    _TripOption(
      'Kota Terlarang',
      'Tiket dewasa musim rendah ¥40 / tinggi ¥60',
      60,
    ),
    _TripOption(
      'Kota Terlarang + taman',
      'Tiket + estimasi transport lokal · ¥80/orang',
      80,
    ),
    _TripOption(
      'Wisata berbayar lebih banyak',
      'Estimasi tiket beberapa lokasi · ¥180/orang',
      180,
    ),
  ];

  int _tripDays = 3;
  int _travelerCount = 1;
  _TripOption _transport = _transportOptions[0];
  _TripOption _hotel = _hotelOptions[1];
  _TripOption _food = _foodOptions[1];
  _TripOption _activity = _activityOptions[2];

  // ─── Quick Converter State ─────────────────────────────────────────────────
  final TextEditingController _amountController = TextEditingController(
    text: '100',
  );
  CurrencyCode _fromCurrency = CurrencyCode.cny;
  CurrencyCode _toCurrency = CurrencyCode.idr;

  // Nilai kurs relatif terhadap 1 USD (Base USD)
  // Kurs mid-market acuan terbaru yang dipakai oleh kalkulator.
  // USD/IDR ≈ 18.143,58 dan CNY/IDR ≈ 2.721,31.
  static const double _rateUsdToIdr = 18143.58;
  static const double _rateUsdToCny = 6.66722277;

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
    _destinationController.dispose();
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
      return val
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]}.',
          );
    }
    return val.toStringAsFixed(2);
  }

  String _formatIdrOnly(double val) {
    return val
        .toStringAsFixed(0)
        .replaceAllMapped(
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
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
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
          children: [_buildChinaTripDashboard(), _buildQuickConverterTab()],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 1: CHINA TRIP BUDGET PLANNER (旅行预算)
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildChinaTripDashboard() {
    const cream = AppColors.mintBackground;
    const red = AppColors.primary;
    const gold = AppColors.coinGold;
    const ink = AppColors.textDark;
    final budgetIdr = _parseBudgetIdr();
    final destination = _destinationController.text.trim().isEmpty
        ? 'Belum dipilih'
        : _destinationController.text.trim();
    final foodBudget = budgetIdr * .25;
    final transportBudget = budgetIdr * .15;
    final lodgingBudget = budgetIdr * .35;
    final activityBudget = budgetIdr * .15;
    final emergencyBudget = budgetIdr * .10;
    final showFeatures = _tripDays < 0;

    Widget metric(IconData icon, String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget feature(
      IconData icon,
      String title,
      String subtitle,
      Color color,
      VoidCallback onTap,
    ) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF1E4D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MY TRAVEL PLANNER',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: ink,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/image/beranda/bg_siang.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '你好, Traveler!',
                            style: TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Let's explore China together.",
                            style: TextStyle(
                              color: AppColors.forestGreen,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: Image.asset(
                        'assets/image/beranda/maskot_01_bintang.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    Container(
                      width: 0,
                      height: 0,
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE4B5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🐼', style: TextStyle(fontSize: 40)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Atur perjalananmu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Budget total (Rp)',
                        prefixText: 'Rp ',
                        prefixIcon: const Icon(
                          Icons.account_balance_wallet_rounded,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _destinationController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Destination',
                        prefixIcon: const Icon(Icons.location_on_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _numberStepper(
                            label: 'Lama perjalanan',
                            value: _tripDays,
                            suffix: 'hari',
                            onMinus: () => setState(
                              () => _tripDays = (_tripDays - 1)
                                  .clamp(1, 30)
                                  .toInt(),
                            ),
                            onPlus: () => setState(
                              () => _tripDays = (_tripDays + 1)
                                  .clamp(1, 30)
                                  .toInt(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _numberStepper(
                            label: 'Jumlah orang',
                            value: _travelerCount,
                            suffix: 'orang',
                            onMinus: () => setState(
                              () => _travelerCount = (_travelerCount - 1)
                                  .clamp(1, 20)
                                  .toInt(),
                            ),
                            onPlus: () => setState(
                              () => _travelerCount = (_travelerCount + 1)
                                  .clamp(1, 20)
                                  .toInt(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Perjalanan saya',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total trip budget',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Rp ${_formatIdrOnly(budgetIdr)}',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                color: red,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: gold,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                        value: .35,
                        minHeight: 9,
                        backgroundColor: Color(0xFFF8EBD2),
                        color: gold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Budget siap dibagi otomatis',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '100% siap dibagi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: gold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  metric(
                    Icons.location_on_rounded,
                    'Destination',
                    destination,
                    red,
                  ),
                  const SizedBox(width: 10),
                  metric(
                    Icons.calendar_month_rounded,
                    'Duration',
                    '$_tripDays Days',
                    gold,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  metric(
                    Icons.restaurant_rounded,
                    'Food budget',
                    'Rp ${_formatIdrOnly(foodBudget)}',
                    const Color(0xFFE89B45),
                  ),
                  const SizedBox(width: 10),
                  metric(
                    Icons.train_rounded,
                    'Transport',
                    'Rp ${_formatIdrOnly(transportBudget)}',
                    const Color(0xFF398A9A),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pembagian budget otomatis',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _allocationRow(
                      Icons.hotel_rounded,
                      'Penginapan',
                      lodgingBudget,
                      '35%',
                      const Color(0xFF398A9A),
                    ),
                    _allocationRow(
                      Icons.restaurant_rounded,
                      'Makanan',
                      foodBudget,
                      '25%',
                      const Color(0xFFE89B45),
                    ),
                    _allocationRow(
                      Icons.train_rounded,
                      'Transportasi',
                      transportBudget,
                      '15%',
                      AppColors.primaryDark,
                    ),
                    _allocationRow(
                      Icons.confirmation_num_rounded,
                      'Tiket wisata',
                      activityBudget,
                      '15%',
                      AppColors.coinGold,
                    ),
                    _allocationRow(
                      Icons.health_and_safety_rounded,
                      'Dana darurat',
                      emergencyBudget,
                      '10%',
                      const Color(0xFF7B61A8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildInlineCurrencyConverter(
                budgetIdr: budgetIdr,
                lodgingBudget: lodgingBudget,
                foodBudget: foodBudget,
                transportBudget: transportBudget,
                activityBudget: activityBudget,
                emergencyBudget: emergencyBudget,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _showChinaTip(
                    'Rencana trip diperbarui',
                    'Budget dan konversi mata uang sudah dihitung dari data perjalananmu.',
                  ),
                  icon: const Icon(Icons.add_road_rounded),
                  label: const Text(
                    'Plan My Trip',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (showFeatures) ...[
                const SizedBox(height: 26),
                const Text(
                  'Bikin perjalanan lebih mudah',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    feature(
                      Icons.currency_exchange_rounded,
                      'IDR ↔ CNY',
                      'Konversi cepat',
                      red,
                      () => _showChinaTip(
                        'Konversi otomatis',
                        'Lihat hasil konversi langsung pada kartu Konversi Mata Uang di halaman ini.',
                      ),
                    ),
                    const SizedBox(width: 10),
                    feature(
                      Icons.restaurant_menu_rounded,
                      'Daily Cost',
                      'Biaya makan',
                      gold,
                      () => _showChinaTip(
                        'China Daily Cost',
                        'Street food sekitar ¥50/hari\nRestoran lokal sekitar ¥90/hari\nRestoran premium mulai ¥180/hari',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    feature(
                      Icons.directions_subway_rounded,
                      'Transport',
                      'Metro & kereta',
                      const Color(0xFF5E7D8A),
                      () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => SizedBox(
                          height: MediaQuery.of(context).size.height * .82,
                          child: _buildTripBudgetPlannerTab(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    feature(
                      Icons.translate_rounded,
                      'Travel Helper',
                      'Frasa Mandarin',
                      const Color(0xFFE06B35),
                      () => _showChinaTip(
                        'Mandarin Travel Helper',
                        '多少钱？\nDuōshǎo qián?\nBerapa harganya?',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              InkWell(
                onTap: () => _showChinaTip(
                  'Budget Alert',
                  'Pengeluaranmu baru 35% dari anggaran.\nMasih aman untuk melanjutkan perjalanan!',
                ),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.notifications_active_rounded, color: red),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Budget Alert  •  Pengingat di 50%, 80%, dan 100%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: red),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Concept mockup · contoh angka untuk ilustrasi, bukan estimasi harga aktual',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChinaTip(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineCurrencyConverter({
    required double budgetIdr,
    required double lodgingBudget,
    required double foodBudget,
    required double transportBudget,
    required double activityBudget,
    required double emergencyBudget,
  }) {
    final budgetCny = budgetIdr * _getRate(CurrencyCode.idr, CurrencyCode.cny);
    final toCny = (double amount) =>
        amount * _getRate(CurrencyCode.idr, CurrencyCode.cny);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.currency_exchange_rounded,
                color: AppColors.primaryDark,
              ),
              SizedBox(width: 8),
              Text(
                'Konversi mata uang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3A2118),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Budget dan seluruh pembagiannya otomatis dikonversi ke Rupiah dan Yuan.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total budget',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                'Rp ${_formatIdrOnly(budgetIdr)}  ≈  ¥ ${_formatNumber(budgetCny, CurrencyCode.cny)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          _convertedAllocationRow(
            'Penginapan',
            lodgingBudget,
            toCny(lodgingBudget),
          ),
          _convertedAllocationRow('Makanan', foodBudget, toCny(foodBudget)),
          _convertedAllocationRow(
            'Transportasi',
            transportBudget,
            toCny(transportBudget),
          ),
          _convertedAllocationRow(
            'Tiket wisata',
            activityBudget,
            toCny(activityBudget),
          ),
          _convertedAllocationRow(
            'Dana darurat',
            emergencyBudget,
            toCny(emergencyBudget),
          ),
          const SizedBox(height: 10),
          const Text(
            'Kurs acuan: 1 CNY ≈ Rp2.721 dan 1 USD ≈ Rp18.144. Nilai dapat berubah saat digunakan.',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _convertedAllocationRow(String label, double idr, double cny) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textDark),
            ),
          ),
          Text(
            'Rp ${_formatIdrOnly(idr)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          Text(
            '¥ ${_formatNumber(cny, CurrencyCode.cny)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberStepper({
    required String label,
    required int value,
    required String suffix,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onMinus,
                icon: const Icon(Icons.remove_circle_outline),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Expanded(
                child: Text(
                  '$value $suffix',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: onPlus,
                icon: const Icon(Icons.add_circle_outline),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _allocationRow(
    IconData icon,
    String label,
    double amount,
    String percentage,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textDark),
            ),
          ),
          Text(
            percentage,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Text(
            'Rp ${_formatIdrOnly(amount)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripBudgetPlannerTab() {
    final budgetIdr = _parseBudgetIdr();
    final rateIdrToCny = _getRate(CurrencyCode.idr, CurrencyCode.cny);
    final rateIdrToUsd = _getRate(CurrencyCode.idr, CurrencyCode.usd);
    final totalCny = budgetIdr * rateIdrToCny;
    final totalUsd = budgetIdr * rateIdrToUsd;

    final nights = _tripDays > 1 ? _tripDays - 1 : 1;
    final cnyTransport = _transport.priceCny * _tripDays * _travelerCount;
    final cnyHotel =
        _hotel.priceCny *
        nights *
        (_hotel.label.startsWith('Hostel')
            ? _travelerCount
            : (_travelerCount / 2).ceil());
    final cnyFood = _food.priceCny * _tripDays * _travelerCount;
    final cnyActivity = _activity.priceCny * _travelerCount;
    final idrTransport = cnyTransport / rateIdrToCny;
    final idrHotel = cnyHotel / rateIdrToCny;
    final idrFood = cnyFood / rateIdrToCny;
    final idrActivity = cnyActivity / rateIdrToCny;
    final plannedCny = cnyTransport + cnyHotel + cnyFood + cnyActivity;
    final remainingCny = totalCny - plannedCny;

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
                        horizontal: 8,
                        vertical: 3,
                      ),
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
                      horizontal: 14,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 2,
                      ),
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
                      _buildBudgetPresetChip(
                        'Rp 2.000.000 (Contoh)',
                        '2.000.000',
                      ),
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
                          horizontal: 12,
                          vertical: 10,
                        ),
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
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
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
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Kurs acuan: 1 CNY ≈ Rp 2.721 IDR | 1 USD ≈ Rp 18.144 IDR (${_lastUpdated.day}/${_lastUpdated.month}/${_lastUpdated.year})',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Pilihan dan estimasi berbasis harga lokal Beijing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sesuaikan rencana perjalanan · Beijing',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTripSettingsCard(),
          const SizedBox(height: 12),
          _buildTripEstimateCard(totalCny, plannedCny, remainingCny),
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
                    Icon(
                      Icons.tips_and_updates_rounded,
                      color: Color(0xFFF59E0B),
                      size: 20,
                    ),
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

  Widget _buildTripSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Lama perjalanan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: _tripDays > 1
                    ? () => setState(() => _tripDays--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_tripDays hari',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _tripDays < 30
                    ? () => setState(() => _tripDays++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Jumlah orang',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: _travelerCount > 1
                    ? () => setState(() => _travelerCount--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_travelerCount',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _travelerCount < 12
                    ? () => setState(() => _travelerCount++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          _buildOptionDropdown(
            'Transportasi',
            _transport,
            _transportOptions,
            (value) => _transport = value,
          ),
          _buildOptionDropdown(
            'Penginapan',
            _hotel,
            _hotelOptions,
            (value) => _hotel = value,
          ),
          _buildOptionDropdown(
            'Makanan',
            _food,
            _foodOptions,
            (value) => _food = value,
          ),
          _buildOptionDropdown(
            'Aktivitas & wisata',
            _activity,
            _activityOptions,
            (value) => _activity = value,
          ),
          const SizedBox(height: 4),
          const Text(
            'Asumsi: kamar hotel berbagi maksimal 2 orang. Acuan resmi Beijing: metro mulai ¥3 (tarif bertingkat menurut jarak); tiket Palace Museum ¥40 musim rendah / ¥60 musim tinggi. Tarif hotel, makan, dan DiDi di atas adalah kisaran perencanaan, bukan penawaran langsung; cek harga saat memesan.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionDropdown(
    String title,
    _TripOption selected,
    List<_TripOption> options,
    ValueChanged<_TripOption> onSelected,
  ) {
    final effectiveValue = options.contains(selected)
        ? selected
        : options.firstWhere(
            (o) => o.label == selected.label && o.priceCny == selected.priceCny,
            orElse: () => options.first,
          );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DropdownButtonFormField<_TripOption>(
        value: effectiveValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: title,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<_TripOption>(
                value: option,
                child: Text(
                  '${option.label} — ${option.detail}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => onSelected(value));
          }
        },
      ),
    );
  }

  Widget _buildTripEstimateCard(
    double budgetCny,
    double plannedCny,
    double remainingCny,
  ) {
    final overBudget = remainingCny < 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: overBudget ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overBudget ? const Color(0xFFFED7AA) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perkiraan biaya pilihanmu',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _estimateRow(
            'Transportasi',
            _transport.priceCny * _tripDays * _travelerCount,
          ),
          _estimateRow(
            'Hotel (${_tripDays > 1 ? _tripDays - 1 : 1} malam)',
            _hotel.priceCny *
                (_tripDays > 1 ? _tripDays - 1 : 1) *
                (_hotel.label.startsWith('Hostel')
                    ? _travelerCount
                    : (_travelerCount / 2).ceil()),
          ),
          _estimateRow('Makanan', _food.priceCny * _tripDays * _travelerCount),
          _estimateRow('Aktivitas', _activity.priceCny * _travelerCount),
          const Divider(),
          Text(
            'Total: ¥ ${_formatNumber(plannedCny, CurrencyCode.cny)}  (≈ Rp ${_formatIdrOnly(plannedCny / _getRate(CurrencyCode.idr, CurrencyCode.cny))})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            overBudget
                ? 'Melebihi anggaran sekitar ¥ ${_formatNumber(-remainingCny, CurrencyCode.cny)}.'
                : 'Sisa anggaran: ¥ ${_formatNumber(remainingCny, CurrencyCode.cny)} dari ¥ ${_formatNumber(budgetCny, CurrencyCode.cny)}.',
            style: TextStyle(
              color: overBudget ? Colors.deepOrange : AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimateRow(String label, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          '¥ ${_formatNumber(value, CurrencyCode.cny)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _buildBudgetPresetChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
        ),
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

  Widget _buildCategoryCard({
    required String titleId,
    required String titleZh,
    required String emoji,
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
          ],
        ),
        subtitle: Text(
          titleZh,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
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
          ...estimates.map(
            (est) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorAccent,
                    ),
                  ),
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
            ),
          ),
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
                ...phrases.map(
                  (ph) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '› $ph',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
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

  // ignore: unused_element
  Widget _buildQuickConverterTab() {
    final inputVal =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final convertedVal = _calculateConverted(inputVal);
    final unitRate = _getRate(_fromCurrency, _toCurrency);
    final showPresetCosts = _amountController.text == '__show_preset_costs__';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp & Status Kurs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sync_rounded,
                  size: 16,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kurs diperbarui: ${_lastUpdated.day}/${_lastUpdated.month}/${_lastUpdated.year} (Offline Cache)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
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
              border: Border.all(color: AppColors.borderLight),
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
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
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

          if (showPresetCosts) ...[
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
          ],

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
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
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
                        color: AppColors.textDark,
                      ),
                    ),
                    trailing: Text(
                      'Rp ${_formatNumber(idr, CurrencyCode.idr)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
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
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
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
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            Text(
              _getMandarinTerm(code),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: onChanged,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            Text(
              _getMandarinTerm(code),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
