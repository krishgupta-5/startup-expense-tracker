import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
// Required for FontFeature
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/financial_data_service.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/currency_preference_service.dart';

class MonthlyBurnScreen extends StatefulWidget {
  const MonthlyBurnScreen({super.key});

  @override
  State<MonthlyBurnScreen> createState() => _MonthlyBurnScreenState();
}

class _MonthlyBurnScreenState extends State<MonthlyBurnScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  String _userCountryCode = '+1'; // Default to USD
  final bool _isLoadingCountry =
      false; // Start as false since we use sync method

  @override
  void initState() {
    super.initState();
    // Get currency preference synchronously for instant display
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    // Listen for currency changes
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _shimmerController.repeat();
    _loadFinancialData();
  }

  @override
  void dispose() {
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    _debounceTimer?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onCurrencyChanged() {
    if (mounted) {
      setState(() {
        _userCountryCode =
            CurrencyPreferenceService.getCurrencyPreferenceSync();
      });
    }
  }

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
  Map<String, Map<String, dynamic>>? _budgetVarianceData;
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

  Future<void> _loadFinancialData() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
      // Reset progressive loading states
      _mainCardLoaded = false;
      _trendLoaded = false;
      _categoriesLoaded = false;
      _teamsLoaded = false;
      _forecastLoaded = false;
    });

    try {
      // Load all data simultaneously for faster loading with individual error handling
      final results = await Future.wait([
        FinancialDataService.getMonthlyBurnData().catchError(
          (e) => <String, dynamic>{},
        ),
        FinancialDataService.getUnifiedTeamCostData().catchError(
          (e) => <String, dynamic>{},
        ),
        FinancialDataService.getRawTeamsData().catchError(
          (e) => <Map<String, dynamic>>[],
        ),
        FinancialDataService.getActualSpendingPerTeam().catchError(
          (e) => <String, double>{},
        ),
        FinancialDataService.getBudgetVarianceAnalysis(
          FirebaseAuth.instance.currentUser!.uid,
        ).catchError((e) => <String, Map<String, dynamic>>{}),
      ]);

      setState(() {
        _financialData = results[0] as Map<String, dynamic>?;
        _teamCostData = results[1] as Map<String, dynamic>?;
        _rawTeamsData = results[2] as List<Map<String, dynamic>>?;
        _actualSpendingPerTeam = results[3] as Map<String, double>?;
        _budgetVarianceData = results[4] as Map<String, Map<String, dynamic>>?;
        // Set all loading states to true at once
        _mainCardLoaded = true;
        _trendLoaded = true;
        _categoriesLoaded = true;
        _teamsLoaded = true;
        _forecastLoaded = true;
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load financial data: ${e.toString()}";
        _isRefreshing = false;
      });
    }
  }

  void _onRangeChanged(String newRange) {
    if (_selectedRange == newRange || _isRefreshing) return;

    // Cancel existing timer
    _debounceTimer?.cancel();

    // Reduce debounce time for better responsiveness
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
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
        return DateTime.now()
            .month; // Returns exactly the number of months since January
      case "ALL":
        return 999; // Large number to grab all available data
      default:
        return 6;
    }
  }

  // --- PREMIUM SECTION LABEL HELPER ---
  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
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

                // Content container - show shimmer immediately when loading
                Column(
                  children: [
                    // Show main card or shimmer
                    _mainCardLoaded
                        ? _buildMainBurnCard()
                        : _buildSkeletonCard(),
                    const SizedBox(height: 32),

                    // Show trend section or shimmer
                    _trendLoaded
                        ? _buildBurnTrendSection()
                        : _buildSkeletonSection(
                            _selectedRange == "YTD" || _selectedRange == "ALL"
                                ? "$_selectedRange Burn Trend"
                                : "${_getMonthsCount()}-Month Burn Trend",
                          ),
                    const SizedBox(height: 32),

                    // Show categories or shimmer
                    _categoriesLoaded
                        ? _buildExpenseCategoriesSection()
                        : _buildSkeletonSection(
                            "TRANSACTION-BASED BUDGET ANALYSIS",
                          ),
                    const SizedBox(height: 32),

                    // Show teams or shimmer
                    _teamsLoaded
                        ? _buildTeamCostSection()
                        : _buildSkeletonSection("TEAM COST DISTRIBUTION"),
                    const SizedBox(height: 32),

                    // Show forecast or shimmer
                    _forecastLoaded
                        ? _buildForecastComparisonSection()
                        : _buildSkeletonSection("TEAM-BASED BUDGET ANALYSIS"),
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
              color: Colors.white.withValues(alpha: 0.05), // White Glass Style
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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

  // --- Standardized Minimal Empty State ---
  Widget _buildEmptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // --- Main Burn Card ---
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
          padding: const EdgeInsets.all(24), // Tighter padding
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
                        fontSize: 10,
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
                        fontSize: 10,
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
                  Expanded(
                    // FIXED: FITTED BOX FOR LARGE NUMBERS
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        grossBurn > 0
                            ? (_isLoadingCountry
                                  ? "₹${grossBurn.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}"
                                  : CurrencyFormatter.formatByCountry(
                                      grossBurn,
                                      _userCountryCode,
                                    ))
                            : (_isLoadingCountry
                                  ? "₹0"
                                  : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0"),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 48, // Bumped size for hero impact
                          fontWeight: FontWeight.w600, // Thicker weight
                          height: 1.0,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 6,
                    ), // align to baseline
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
                      "Net Burn",
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // FIXED: FITTED BOX FOR LARGE NUMBERS
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        netBurn > 0
                            ? (_isLoadingCountry
                                  ? "₹${netBurn.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}"
                                  : CurrencyFormatter.formatByCountry(
                                      netBurn,
                                      _userCountryCode,
                                    ))
                            : (_isLoadingCountry
                                  ? "₹0"
                                  : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0"),
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFF453A),
                          fontSize: 24, // Bumped size slightly
                          fontWeight: FontWeight.w600,
                        ),
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

    List<Map<String, dynamic>> displayData = [];

    if (trendData.isNotEmpty) {
      if (trendData.length > count) {
        displayData = trendData.sublist(trendData.length - count);
      } else {
        displayData = trendData;
      }
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
            _buildSectionLabel(title),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: displayData.isEmpty
                  ? _buildEmptyState("Not enough data for trend analysis")
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Dynamically calculate bar width to fit ALL and YTD on screen perfectly
                        final int barCount = displayData.length;
                        final double totalGapSpace = barCount > 1
                            ? (barCount - 1) * 8.0
                            : 0.0;
                        double barWidth =
                            (constraints.maxWidth - totalGapSpace) / barCount;
                        if (barWidth > 40.0) {
                          barWidth = 40.0; // Cap width at 40px
                        }

                        return SizedBox(
                          height: 160,
                          child: Row(
                            mainAxisAlignment: barCount <= 3
                                ? MainAxisAlignment.spaceEvenly
                                : MainAxisAlignment.spaceBetween,
                            // FIX 1: Ensure the Row gives bounded height to its children
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: displayData.map((data) {
                              final amount = _toDouble(data['amount']);
                              final percentage = maxAmount > 0
                                  ? amount / maxAmount
                                  : 0.0;
                              return _buildFlatBar(
                                data['month'] as String,
                                percentage,
                                barWidth,
                                amount,
                                isActive:
                                    data['isCurrentMonth'] as bool? ?? false,
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatBar(
    String label,
    double pct,
    double width,
    double amount, {
    bool isActive = false,
  }) {
    // FIX 2: Scale 0 to 2% (0.02) so it's not completely invisible,
    // otherwise strictly use the percentage scale for the height.
    final safePct = pct == 0.0 ? 0.02 : pct.clamp(0.0, 1.0);

    // Truncate the month label slightly if width is getting very small (like in 'ALL' view)
    String displayLabel = label;
    if (width < 25 && displayLabel.length > 1) {
      displayLabel = displayLabel.substring(0, 1);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            _isLoadingCountry
                ? "₹${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}"
                : CurrencyFormatter.formatByCountry(amount, _userCountryCode),
            style: GoogleFonts.inter(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        // FIX 3: Use Expanded and FractionallySizedBox to apply the percentage to the height
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: safePct,
              child: Container(
                width: width,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : const Color(0xFF1F1F22),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          displayLabel,
          style: GoogleFonts.inter(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildExpenseCategoriesSection() {
    if (_error != null) return _buildErrorSection("Budget Variance Analysis");

    // Get category breakdown from monthly burn data (transaction-based)
    final categoryBreakdown =
        _financialData?['categoryBreakdown'] as Map<String, double>? ?? {};
    final budgetVariance = _budgetVarianceData ?? {};

    // Combine both sources: transaction data + budget variance
    Map<String, dynamic> combinedData = {};

    // Start with transaction-based categories
    for (var entry in categoryBreakdown.entries) {
      combinedData[entry.key] = {
        'actual': entry.value,
        'budget': 0.0,
        'variance': -entry.value, // negative means over budget if no budget set
        'variancePercentage': 0.0,
        'isOverBudget': true,
        'hasBudget': false,
      };
    }

    // Overlay budget data where available
    for (var entry in budgetVariance.entries) {
      combinedData[entry.key] = entry.value;
    }

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
            _buildSectionLabel("TRANSACTION-BASED BUDGET ANALYSIS"),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Builder(
                builder: (context) {
                  final sortedEntries = combinedData.entries
                      .where(
                        (entry) =>
                            (entry.value['actual'] as double? ?? 0.0) > 0,
                      )
                      .toList();
                  sortedEntries.sort(
                    (a, b) => (b.value['actual'] as double).compareTo(
                      a.value['actual'] as double,
                    ),
                  );

                  return combinedData.isEmpty
                      ? _buildEmptyState("No transaction data available")
                      : Column(
                          children: [
                            // Header row
                            _buildBudgetVarianceHeader(),
                            const SizedBox(height: 16),
                            // Category rows - sort by actual amount descending
                            ...sortedEntries.map((entry) {
                              final categoryData = entry.value;
                              final budget =
                                  categoryData['budget'] as double? ?? 0.0;
                              final actual =
                                  categoryData['actual'] as double? ?? 0.0;
                              final variance =
                                  categoryData['variance'] as double? ?? 0.0;
                              final variancePercentage =
                                  categoryData['variancePercentage']
                                      as double? ??
                                  0.0;
                              final isOverBudget =
                                  categoryData['isOverBudget'] as bool? ??
                                  false;
                              final hasBudget =
                                  categoryData['hasBudget'] as bool? ?? false;

                              return _buildBudgetVarianceRow(
                                _getCategoryDisplayName(entry.key),
                                budget,
                                actual,
                                variance,
                                variancePercentage,
                                isOverBudget,
                                hasBudget,
                              );
                            }).toList(),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCostSection() {
    if (_error != null) return _buildErrorSection("Team Cost Distribution");

    final teamCosts =
        (_teamCostData?['teamCosts'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

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
            _buildSectionLabel("TEAM COST DISTRIBUTION"),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: teamCosts.isEmpty
                  ? _buildEmptyState("No team data available")
                  : Column(
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
                                // FIXED: FITTED BOX FOR LARGE NUMBERS
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _isLoadingCountry
                                        ? "₹${_toDouble(team['cost']).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}"
                                        : CurrencyFormatter.formatByCountry(
                                            _toDouble(team['cost']),
                                            _userCountryCode,
                                          ),
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
                                          borderRadius: BorderRadius.circular(
                                            2,
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
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrencyForForecast(double amount) {
    return _isLoadingCountry
        ? '₹${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}'
        : CurrencyFormatter.formatByCountry(amount, _userCountryCode);
  }

  Widget _buildForecastComparisonSection() {
    if (_error != null) return _buildErrorSection("Budget vs Actual");

    final rawTeamsData = _rawTeamsData ?? [];

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
            _buildSectionLabel("TEAM-BASED BUDGET ANALYSIS"),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: rawTeamsData.isEmpty
                  ? _buildEmptyState("No team budget data available")
                  : _buildForecastDataContent(rawTeamsData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastDataContent(List<Map<String, dynamic>> rawTeamsData) {
    double totalBudget = 0;
    double totalActual = 0;
    List<Map<String, dynamic>> comparisonData = [];

    for (var team in rawTeamsData) {
      final teamName = team['teamName'] as String? ?? 'Unknown Team';

      // Handle budget parsing for different data types and formats
      dynamic budgetData = team['monthlyBudget'];
      double budget = 0.0;

      if (budgetData != null) {
        if (budgetData is double) {
          budget = budgetData;
        } else if (budgetData is int) {
          budget = budgetData.toDouble();
        } else if (budgetData is String) {
          // Remove currency symbols, commas, and other non-numeric characters except decimal point
          String budgetStr = budgetData.replaceAll(RegExp(r'[^\d.]'), '');
          budget = double.tryParse(budgetStr) ?? 0.0;
        }
      }

      // Use null-aware access with fallback to 0 for teams with no spending
      final actual = _toDouble(
        _actualSpendingPerTeam?[teamName],
        fallback: 0.0,
      );
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

    return Column(
      children: [
        _buildComparisonRow("Team", "Budget", "Actual", "Variance", true),
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
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
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
            // FIXED: FITTED BOX FOR LARGE NUMBERS
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _formatCurrencyForForecast(totalBudget),
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
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
            // FIXED: FITTED BOX FOR LARGE NUMBERS
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _formatCurrencyForForecast(totalActual),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
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
            // FIXED: FITTED BOX FOR LARGE NUMBERS
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
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
              ),
            ),
          ],
        ),
      ],
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
            // FIXED: FITTED BOX FOR LARGE NUMBERS
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
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
          ),
          Expanded(
            flex: 4,
            // FIXED: FITTED BOX FOR LARGE NUMBERS
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
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
          ),
          Expanded(
            flex: 4,
            // FIXED: FITTED BOX FOR LARGE NUMBERS
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
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
          ),
        ],
      ),
    );
  }

  // --- Minimal Error State Components ---
  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Text(
            "Failed to load financial data",
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadFinancialData,
            child: Text(
              "Tap to retry",
              style: GoogleFonts.inter(
                color: const Color(0xFF30D158),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(title),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: _buildEmptyState("Failed to load data"),
        ),
      ],
    );
  }

  // --- Skeleton Loading Components ---
  Widget _buildSkeletonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          final value = _shimmerController.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment(value - 1, 0),
                        end: Alignment(value, 0),
                        colors: [
                          Colors.white.withValues(alpha: 0.03),
                          Colors.white.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.03),
                        ],
                        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 80,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment(value - 1, 0),
                        end: Alignment(value, 0),
                        colors: [
                          Colors.white.withValues(alpha: 0.03),
                          Colors.white.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.03),
                        ],
                        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Container(
                width: 200,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    begin: Alignment(value - 1, 0),
                    end: Alignment(value, 0),
                    colors: [
                      Colors.white.withValues(alpha: 0.03),
                      Colors.white.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.03),
                    ],
                    stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 120,
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment(value - 1, 0),
                            end: Alignment(value, 0),
                            colors: [
                              Colors.white.withValues(alpha: 0.03),
                              Colors.white.withValues(alpha: 0.06),
                              Colors.white.withValues(alpha: 0.10),
                              Colors.white.withValues(alpha: 0.06),
                              Colors.white.withValues(alpha: 0.03),
                            ],
                            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 100,
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment(value - 1, 0),
                            end: Alignment(value, 0),
                            colors: [
                              Colors.white.withValues(alpha: 0.03),
                              Colors.white.withValues(alpha: 0.06),
                              Colors.white.withValues(alpha: 0.10),
                              Colors.white.withValues(alpha: 0.06),
                              Colors.white.withValues(alpha: 0.03),
                            ],
                            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShimmerEffect(double width, double height) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final value = _shimmerController.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(value - 1, 0),
              end: Alignment(value, 0),
              colors: [
                Colors.white.withValues(alpha: 0.03),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.03),
              ],
              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(title),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShimmerEffect(double.infinity, 16),
              const SizedBox(height: 16),
              _buildShimmerEffect(double.infinity, 16),
              const SizedBox(height: 16),
              _buildShimmerEffect(200, 16),
            ],
          ),
        ),
      ],
    );
  }

  String _getCategoryDisplayName(String categoryKey) {
    // Map category keys to proper display names matching budget settings
    switch (categoryKey) {
      case 'salaries':
        return 'Salary';
      case 'marketing':
        return 'Marketing';
      case 'infrastructure':
        return 'Infrastructure';
      case 'office':
        return 'Office Rent';
      case 'software':
        return 'Software';
      case 'hardware':
        return 'Hardware';
      case 'transport':
        return 'Transport';
      case 'design':
        return 'Design';
      case 'others':
        return 'Others';
      case 'travel':
        return 'Travel';
      case 'meals':
        return 'Meals';
      case 'contractors':
        return 'Contractors';
      case 'legal':
        return 'Legal';
      default:
        return _capitalizeFirstLetter(categoryKey);
    }
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Widget _buildBudgetVarianceHeader() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            'Category',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Budget',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Actual',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Variance',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetVarianceRow(
    String category,
    double budget,
    double actual,
    double variance,
    double variancePercentage,
    bool isOverBudget,
    bool hasBudget,
  ) {
    final varianceColor = isOverBudget
        ? const Color(0xFFFF453A)
        : const Color(0xFF30D158);
    final varianceText = isOverBudget
        ? '${variancePercentage.abs().toStringAsFixed(1)}% over'
        : '${variancePercentage.abs().toStringAsFixed(1)}% under';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!hasBudget)
                  Text(
                    'No budget set',
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatCurrencyForForecast(budget),
              style: GoogleFonts.inter(
                color: hasBudget ? Colors.white38 : Colors.white24,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatCurrencyForForecast(actual),
              style: GoogleFonts.inter(
                color: actual > 0 ? Colors.white : Colors.white24,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrencyForForecast(variance.abs()),
                  style: GoogleFonts.inter(
                    color: varianceColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
                if (hasBudget)
                  Text(
                    varianceText,
                    style: GoogleFonts.inter(
                      color: varianceColor.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
