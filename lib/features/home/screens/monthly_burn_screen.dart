import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
// Required for FontFeature
import 'package:google_fonts/google_fonts.dart';
import '../../../services/financial_data_service.dart';
import '../../../services/financial_calculator.dart';

class MonthlyBurnScreen extends StatefulWidget {
  const MonthlyBurnScreen({super.key});

  @override
  State<MonthlyBurnScreen> createState() => _MonthlyBurnScreenState();
}

class _MonthlyBurnScreenState extends State<MonthlyBurnScreen> {
  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  String _selectedRange = "6M";
  final List<String> _ranges = ["1M", "3M", "6M", "YTD", "ALL"];

  Map<String, dynamic>? _financialData;
  Map<String, dynamic>? _teamCostData;
  List<Map<String, dynamic>>? _rawTeamsData;
  Map<String, double>? _actualSpendingPerTeam;

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  // Progressive loading states
  bool _mainCardLoaded = false;
  bool _trendLoaded = false;
  bool _categoriesLoaded = false;
  bool _teamsLoaded = false;
  bool _forecastLoaded = false;

  // Debouncing
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFinancialData() async {
    setState(() {
      if (_financialData == null) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
      _error = null;
      // Reset progressive loading states
      _mainCardLoaded = false;
      _trendLoaded = false;
      _categoriesLoaded = false;
      _teamsLoaded = false;
      _forecastLoaded = false;
    });

    try {
      // Load data progressively for better UX
      final futures = await Future.wait([
        FinancialDataService.getMonthlyBurnData(),
        FinancialDataService.getTeamCostDistribution(),
        FinancialDataService.getRawTeamsData(),
        FinancialDataService.getActualSpendingPerTeam(),
      ]);

      setState(() {
        _financialData = futures[0] as Map<String, dynamic>;
        _mainCardLoaded = true;
        _trendLoaded = true;
        _categoriesLoaded = true;
      });

      // Load team data with a small delay for progressive effect
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _teamCostData = futures[1] as Map<String, dynamic>;
        _teamsLoaded = true;
      });

      // Load forecast data last
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _rawTeamsData = futures[2] as List<Map<String, dynamic>>;
        _actualSpendingPerTeam = futures[3] as Map<String, double>;
        _forecastLoaded = true;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _onRangeChanged(String newRange) {
    if (_selectedRange == newRange || _isRefreshing) return;

    // Cancel existing timer
    _debounceTimer?.cancel();

    // Set new timer for debouncing
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() => _selectedRange = newRange);
      _loadFinancialData();
    });
  }

  int _getMonthsCount() {
    switch (_selectedRange) {
      case "1M":
        return 1;
      case "3M":
        return 3;
      case "6M":
        return 6;
      case "YTD":
        return DateTime.now().month;
      case "ALL":
        return 12;
      default:
        return 6;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildRangeSelector(),
                const SizedBox(height: 32),

                // Content container without blue overlay during tab switching
                Column(
                  children: [
                    // Progressive loading for main card
                    _mainCardLoaded
                        ? _buildMainBurnCard()
                        : _buildSkeletonCard(),
                    const SizedBox(height: 32),

                    // Progressive loading for trend section
                    _trendLoaded
                        ? _buildBurnTrendSection()
                        : _buildSkeletonSection("Burn Trend"),
                    const SizedBox(height: 32),

                    // Progressive loading for categories
                    _categoriesLoaded
                        ? _buildExpenseCategoriesSection()
                        : _buildSkeletonSection("Expense Categories"),
                    const SizedBox(height: 32),

                    // Progressive loading for teams
                    _teamsLoaded
                        ? _buildTeamCostSection()
                        : _buildSkeletonSection("Team Cost Distribution"),
                    const SizedBox(height: 32),

                    // Vendor section (always shown, no loading needed)
                    _buildVendorBreakdownSection(),
                    const SizedBox(height: 32),

                    // Progressive loading for forecast
                    _forecastLoaded
                        ? _buildForecastComparisonSection()
                        : _buildSkeletonSection("Budget vs Actual"),
                    const SizedBox(height: 40),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "Burn Analysis",
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Expense Breakdown",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Range Selector ---
  Widget _buildRangeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _ranges.map((range) {
          final isSelected = _selectedRange == range;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _onRangeChanged(range);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  range,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Main Burn Card ---
  // FIX: Removed the dead _isLoading / _error guards inside this method.
  // This widget is only ever called from the build tree when _mainCardLoaded == true,
  // which means loading has already succeeded. The inner guards could never show
  // their loading/error states, and caused the real error card to be unreachable.
  Widget _buildMainBurnCard() {
    if (_error != null) return _buildErrorCard();

    final grossBurn = _toDouble(_financialData?['grossBurn']);
    final netBurn = _toDouble(_financialData?['netBurn']);

    return AnimatedOpacity(
      opacity: _mainCardLoaded ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: AnimatedSlide(
        offset: _mainCardLoaded ? Offset.zero : const Offset(0, 0.1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9F0A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      "PRIMARY INSIGHT",
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF9F0A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF30D158).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: const Color(0xFF30D158).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      "HIGH IMPACT",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF30D158),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    grossBurn > 0
                        ? "₹${grossBurn.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}"
                        : "—",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      height: 1.0,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "/month",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Net Burn (after revenue)",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      netBurn > 0
                          ? "₹${netBurn.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}"
                          : "—",
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF453A),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Burn Trend ---
  Widget _buildBurnTrendSection() {
    int count = _getMonthsCount();
    String title = _selectedRange == "YTD" || _selectedRange == "ALL"
        ? "$_selectedRange Burn Trend"
        : "$count-Month Burn Trend";

    if (_error != null) return _buildErrorSection(title);

    List<Map<String, dynamic>> trendData = List<Map<String, dynamic>>.from(
      _financialData?['trendData'] ?? [],
    );

    List<Map<String, dynamic>> displayData;

    if (trendData.isNotEmpty) {
      if (trendData.length > count) {
        displayData = trendData.sublist(trendData.length - count);
      } else {
        displayData = trendData;
      }
    } else {
      displayData = _getFallbackTrendData(count);
    }

    final maxAmount = displayData.isEmpty
        ? 1.0
        : displayData
              .map((d) => _toDouble(d['amount']))
              .reduce((a, b) => a > b ? a : b);

    return AnimatedOpacity(
      opacity: _trendLoaded ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: AnimatedSlide(
        offset: _trendLoaded ? Offset.zero : const Offset(0, 0.1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: SizedBox(
                height: 160,
                child: Row(
                  mainAxisAlignment: displayData.length <= 3
                      ? MainAxisAlignment.spaceEvenly
                      : MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: displayData.map((data) {
                    final amount = _toDouble(data['amount']);
                    final percentage = maxAmount > 0 ? amount / maxAmount : 0.0;
                    return _buildFlatBar(
                      data['month'] as String,
                      percentage,
                      isActive: data['isCurrentMonth'] as bool? ?? false,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatBar(String label, double pct, {bool isActive = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: 120 * pct,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : const Color(0xFF1F1F22),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- Fallback Data Method ---
  List<Map<String, dynamic>> _getFallbackTrendData(int count) {
    final now = DateTime.now();
    final fallbackData = <Map<String, dynamic>>[];
    final baseAmount = 0;
    final variations = [
      0.9,
      1.1,
      0.95,
      1.05,
      0.85,
      1.0,
      1.02,
      0.98,
      1.15,
      0.88,
      0.92,
      1.08,
    ];

    for (int i = count - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final variationIndex = i % variations.length;
      final amount = baseAmount * variations[variationIndex];
      fallbackData.add({
        'month': _getMonthAbbreviation(month.month),
        'amount': amount,
        'isCurrentMonth': i == 0,
      });
    }

    return fallbackData;
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1) % 12];
  }

  // --- Skeleton Loading Components ---
  Widget _buildSkeletonCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildShimmerEffect(80, 24),
                const Spacer(),
                _buildShimmerEffect(80, 24),
              ],
            ),
            const SizedBox(height: 40),
            _buildShimmerEffect(200, 40),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerEffect(double width, double height) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildSkeletonSection(String title) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerEffect(150, 24),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Center(
              child: AnimatedOpacity(
                opacity: 0.3,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF453A), size: 48),
          const SizedBox(height: 16),
          Text(
            "Failed to load financial data",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? "Unknown error",
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadFinancialData,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF30D158).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF30D158).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                "Retry",
                style: GoogleFonts.inter(
                  color: const Color(0xFF30D158),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Center(
            child: Text(
              "Failed to load data",
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseCategoriesSection() {
    if (_error != null) return _buildErrorSection("Expense Categories");

    final categoryBreakdown =
        _financialData?['categoryBreakdown'] as Map<String, double>? ?? {};
    final totalExpenses = _toDouble(_financialData?['totalExpenses']);

    if (categoryBreakdown.isEmpty) {
      return AnimatedOpacity(
        opacity: _categoriesLoaded ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        child: AnimatedSlide(
          offset: _categoriesLoaded ? Offset.zero : const Offset(0, 0.1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Expense Categories",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.pie_chart_outline,
                      color: Colors.white24,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No expense data available",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Add expenses to see category breakdown",
                      style: GoogleFonts.inter(
                        color: Colors.white24,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final categories = categoryBreakdown.map(
      (key, value) =>
          MapEntry(key, {'amount': value, 'color': _getCategoryColor(key)}),
    );

    return AnimatedOpacity(
      opacity: _categoriesLoaded ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: AnimatedSlide(
        offset: _categoriesLoaded ? Offset.zero : const Offset(0, 0.1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Expense Categories",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Column(
                children: categories.entries.map((entry) {
                  final amount = _toDouble(entry.value['amount']);
                  final color = entry.value['color'] as Color;
                  final percentage = FinancialCalculator.calculatePercentage(
                    amount: amount,
                    total: totalExpenses,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildCategoryRow(
                      _capitalizeFirstLetter(entry.key),
                      "₹${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}",
                      percentage,
                      color,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'salaries':
      case 'salary':
        return const Color(0xFF30D158);
      case 'servers':
      case 'infrastructure':
      case 'servers & infrastructure':
        return const Color(0xFF3A4B8A);
      case 'marketing':
        return const Color(0xFFFF9F0A);
      case 'office':
      case 'operations':
      case 'office & operations':
        return const Color(0xFF00BFA5);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  Widget _buildTeamCostSection() {
    if (_error != null) return _buildErrorSection("Team Cost Distribution");

    final teamCosts =
        (_teamCostData?['teamCosts'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    if (teamCosts.isEmpty) {
      return AnimatedOpacity(
        opacity: _teamsLoaded ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        child: AnimatedSlide(
          offset: _teamsLoaded ? Offset.zero : const Offset(0, 0.1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Team Cost Distribution",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      color: Colors.white24,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No team data available",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Create teams and add members to see cost distribution",
                      style: GoogleFonts.inter(
                        color: Colors.white24,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedOpacity(
      opacity: _teamsLoaded ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: AnimatedSlide(
        offset: _teamsLoaded ? Offset.zero : const Offset(0, 0.1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Team Cost Distribution",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Column(
                children: teamCosts.map((team) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            team['name'] as String,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            team['cost'] as String,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [
                                const FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Stack(
                            children: [
                              Container(
                                height: 4,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F1F22),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: _toDouble(team['pct']) > 0
                                    ? _toDouble(team['pct'])
                                    : 0.05,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: _toDouble(team['pct']) > 0
                                        ? Colors.white
                                        : Colors.white24,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(
    String label,
    String value,
    int percentage,
    Color color,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.left,
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 80,
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100.0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Widget _buildVendorBreakdownSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Top Vendors",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildVendorRow("AWS", "Cloud Services", "₹3,800/month"),
                    const SizedBox(height: 16),
                    _buildVendorRow(
                      "Google Workspace",
                      "Productivity",
                      "₹450/month",
                    ),
                    const SizedBox(height: 16),
                    _buildVendorRow("Slack", "Communication", "₹350/month"),
                    const SizedBox(height: 16),
                    _buildVendorRow("HubSpot", "Marketing", "₹1,200/month"),
                  ],
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0A84FF,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: const Color(
                              0xFF0A84FF,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          "COMING SOON",
                          style: GoogleFonts.inter(
                            color: const Color(0xFF0A84FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Vendor analytics will be available",
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "in the next update",
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVendorRow(String name, String service, String cost) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                name.substring(0, 2).toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  service,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            cost,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // FIX: Removed unused _formatCurrency method that was causing a lint warning.
  // All currency formatting is done inline with replaceAllMapped for consistency.
  String _formatCurrencyForForecast(double amount) {
    final intAmount = amount.round();
    return '₹${intAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
  }

  Widget _buildForecastComparisonSection() {
    if (_error != null) return _buildErrorSection("Budget vs Actual");

    final rawTeamsData = _rawTeamsData ?? [];

    if (rawTeamsData.isEmpty) {
      return AnimatedOpacity(
        opacity: _forecastLoaded ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        child: AnimatedSlide(
          offset: _forecastLoaded ? Offset.zero : const Offset(0, 0.1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Budget vs Actual",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white24,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No team budget data available",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Create teams and set budgets to see comparison",
                      style: GoogleFonts.inter(
                        color: Colors.white24,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    double totalBudget = 0;
    double totalActual = 0;
    List<Map<String, dynamic>> comparisonData = [];

    for (var team in rawTeamsData) {
      final teamName = team['teamName'] as String? ?? 'Unknown Team';
      String budgetStr = (team['monthlyBudget']?.toString() ?? '0');
      budgetStr = budgetStr.replaceAll(RegExp(r'[^\d.]'), '');
      final budget = double.tryParse(budgetStr) ?? 0.0;
      final actual = _toDouble(_actualSpendingPerTeam?[teamName]);
      final variance = budget - actual;

      totalBudget += budget;
      totalActual += actual;

      comparisonData.add({
        'team': teamName,
        'budget': budget,
        'actual': actual,
        'variance': variance,
        'isOver': variance < 0,
      });
    }

    return AnimatedOpacity(
      opacity: _forecastLoaded ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: AnimatedSlide(
        offset: _forecastLoaded ? Offset.zero : const Offset(0, 0.1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Budget vs Actual",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Column(
                children: [
                  _buildComparisonRow(
                    "Team",
                    "Budget",
                    "Actual",
                    "Variance",
                    true,
                  ),
                  ...comparisonData.map(
                    (data) => _buildComparisonRow(
                      data['team'] as String,
                      _formatCurrencyForForecast(data['budget'] as double),
                      _formatCurrencyForForecast(data['actual'] as double),
                      data['isOver'] as bool
                          ? "${_formatCurrencyForForecast((data['variance'] as double).abs())} over"
                          : "${_formatCurrencyForForecast((data['variance'] as double).abs())} under",
                      false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Budget",
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatCurrencyForForecast(totalBudget),
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Actual",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatCurrencyForForecast(totalActual),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Variance",
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        totalBudget >= totalActual
                            ? "${_formatCurrencyForForecast(totalBudget - totalActual)} under budget"
                            : "${_formatCurrencyForForecast(totalActual - totalBudget)} over budget",
                        style: GoogleFonts.inter(
                          color: totalBudget >= totalActual
                              ? const Color(0xFF30D158)
                              : const Color(0xFFFF453A),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
    String category,
    String budget,
    String actual,
    String variance,
    bool isHeader,
  ) {
    bool isOver = variance.contains("over");
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              category,
              style: GoogleFonts.inter(
                color: isHeader ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              budget,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                color: isHeader ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              actual,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                color: isHeader ? Colors.white : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              isHeader
                  ? variance
                  : variance.replaceAll(" under", "").replaceAll(" over", ""),
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                color: isHeader
                    ? Colors.white
                    : isOver
                    ? const Color(0xFFFF453A)
                    : const Color(0xFF30D158),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
