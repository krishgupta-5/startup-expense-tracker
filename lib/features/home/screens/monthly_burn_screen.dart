import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/financial_data_service.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/currency_preference_service.dart';
import '../../../theme/app_theme.dart';

class MonthlyBurnScreen extends StatefulWidget {
  const MonthlyBurnScreen({super.key});

  @override
  State<MonthlyBurnScreen> createState() => _MonthlyBurnScreenState();
}

class _MonthlyBurnScreenState extends State<MonthlyBurnScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  String _userCountryCode = '+1'; // Default to USD
  final bool _isLoadingCountry = false; 

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
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    _expensesSubscription?.cancel();
    _teamMembersSubscription?.cancel();
    _companySubscription?.cancel();
    _debounceTimer?.cancel();
    _realtimeDebounceTimer?.cancel();
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
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^\d.-]'), '')) ??
          fallback;
    }
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
  Timer? _realtimeDebounceTimer;

  // Real-time listener subscriptions
  StreamSubscription? _expensesSubscription;
  StreamSubscription? _teamMembersSubscription;
  StreamSubscription? _companySubscription;

  Future<void> _loadFinancialData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isRefreshing = true;
        _error = null;
        _mainCardLoaded = false;
        _trendLoaded = false;
        _categoriesLoaded = false;
        _teamsLoaded = false;
        _forecastLoaded = false;
      });
    } else {
      if (mounted) {
        setState(() {
          _isRefreshing = true;
          _error = null;
        });
      }
    }

    try {
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

      if (mounted) {
        setState(() {
          _financialData = results[0] as Map<String, dynamic>?;
          _teamCostData = results[1] as Map<String, dynamic>?;
          _rawTeamsData = results[2] as List<Map<String, dynamic>>?;
          _actualSpendingPerTeam = results[3] as Map<String, double>?;
          _budgetVarianceData = results[4] as Map<String, Map<String, dynamic>>?;
          
          _mainCardLoaded = true;
          _trendLoaded = true;
          _categoriesLoaded = true;
          _teamsLoaded = true;
          _forecastLoaded = true;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load financial data: ${e.toString()}";
          _isRefreshing = false;
        });
      }
    }
  }

  void _setupRealtimeListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen to changes in the expenses collection
    _expensesSubscription = FirebaseFirestore.instance
        .collection('expenses')
        .where('uid', isEqualTo: user.uid)
        .snapshots()
        .listen((_) {
      _handleRealtimeUpdate();
    });

    // Listen to changes in the team_members collection
    _teamMembersSubscription = FirebaseFirestore.instance
        .collection('members')
        .where('uid', isEqualTo: user.uid)
        .snapshots()
        .listen((_) {
      _handleRealtimeUpdate();
    });

    // Listen to changes in the companies document
    _companySubscription = FirebaseFirestore.instance
        .collection('companies')
        .doc(user.uid)
        .snapshots()
        .listen((_) {
      _handleRealtimeUpdate();
    });
  }

  void _handleRealtimeUpdate() {
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      FinancialDataService.clearAllCache();
      _loadFinancialData(silent: true);
    });
  }

  void _onRangeChanged(String newRange) {
    if (_selectedRange == newRange || _isRefreshing) return;

    _debounceTimer?.cancel();
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
        return DateTime.now().month;
      case "ALL":
        return 999;
      default:
        return 6;
    }
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: context.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: context.isDarkMode
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
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

                Column(
                  children: [
                    _mainCardLoaded
                        ? _buildMainBurnCard()
                        : _buildSkeletonCard(),
                    const SizedBox(height: 32),

                    _trendLoaded
                        ? _buildBurnTrendSection()
                        : _buildSkeletonSection(
                            _selectedRange == "YTD" || _selectedRange == "ALL"
                                ? "$_selectedRange Burn Trend"
                                : "${_getMonthsCount()}-Month Burn Trend",
                          ),
                    const SizedBox(height: 32),

                    _categoriesLoaded
                        ? _buildExpenseCategoriesSection()
                        : _buildSkeletonSection(
                            "TRANSACTION-BASED BUDGET ANALYSIS",
                          ),
                    const SizedBox(height: 32),

                    _teamsLoaded
                        ? _buildTeamCostSection()
                        : _buildSkeletonSection("TEAM COST DISTRIBUTION"),
                    const SizedBox(height: 32),

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
              color: context.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Icon(Icons.arrow_back, color: context.iconPrimary, size: 20),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "Burn Analysis",
              style: GoogleFonts.inter(
                color: context.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Expense Breakdown",
              style: GoogleFonts.inter(
                color: context.textPrimary,
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

  Widget _buildRangeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
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
                      ? (context.isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  range,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: isSelected ? context.textPrimary : context.textTertiary,
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

  Widget _buildEmptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: context.textTertiary,
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.borderColor),
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        grossBurn > 0
                            ? (_isLoadingCountry
                                  ? CurrencyFormatter.formatCompact(grossBurn, countryCode: '+91')
                                  : CurrencyFormatter.formatByCountryCompact(
                                      grossBurn,
                                      _userCountryCode,
                                    ))
                            : (_isLoadingCountry
                                  ? "₹0"
                                  : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0"),
                        style: GoogleFonts.inter(
                          color: context.textPrimary,
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      "/month",
                      style: GoogleFonts.inter(
                        color: context.textSecondary,
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
                  color: context.cardSecondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.borderSubtle,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Net Burn",
                      style: GoogleFonts.inter(
                        color: context.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        netBurn > 0
                            ? (_isLoadingCountry
                                  ? CurrencyFormatter.formatCompact(netBurn, countryCode: '+91')
                                  : CurrencyFormatter.formatByCountryCompact(
                                      netBurn,
                                      _userCountryCode,
                                    ))
                            : (_isLoadingCountry
                                  ? "₹0"
                                  : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0"),
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFF453A),
                          fontSize: 24,
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
      // CHECK IF ARRAY IS NEWEST-FIRST FROM BACKEND
      bool isNewestFirst = trendData.first['isCurrentMonth'] == true;

      if (isNewestFirst) {
        displayData = trendData.take(count).toList();
        displayData = displayData.reversed.toList();
      } else {
        if (trendData.length > count) {
          displayData = trendData.sublist(trendData.length - count);
        } else {
          displayData = trendData;
        }
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
                color: context.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.borderColor),
              ),
              child: displayData.isEmpty
                  ? _buildEmptyState("Not enough data for trend analysis")
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final int barCount = displayData.length;
                        final double totalGapSpace = barCount > 1
                            ? (barCount - 1) * 8.0
                            : 0.0;
                        double barWidth =
                            (constraints.maxWidth - totalGapSpace) / barCount;
                        if (barWidth > 40.0) {
                          barWidth = 40.0; 
                        }

                        return SizedBox(
                          height: 160,
                          child: Row(
                            mainAxisAlignment: barCount <= 3
                                ? MainAxisAlignment.spaceEvenly
                                : MainAxisAlignment.spaceBetween,
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
    final safePct = pct == 0.0 ? 0.02 : pct.clamp(0.0, 1.0);

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
                ? CurrencyFormatter.formatCompact(amount, countryCode: '+91')
                : CurrencyFormatter.formatByCountryCompact(amount, _userCountryCode),
            style: GoogleFonts.inter(
              color: isActive ? context.textPrimary : context.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: safePct,
              child: Container(
                width: width,
                decoration: BoxDecoration(
                  color: isActive ? context.textPrimary : context.cardSecondaryBackground,
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
            color: isActive ? context.textPrimary : context.textTertiary,
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

    // TYPE-SAFE PARSING FOR FIRESTORE MAPS
    final rawCategories = _financialData?['categoryBreakdown'] as Map<String, dynamic>? ?? {};
    final Map<String, double> categoryBreakdown = {};
    rawCategories.forEach((k, v) {
      categoryBreakdown[k] = _toDouble(v);
    });

    final budgetVariance = _budgetVarianceData ?? {};

    Map<String, dynamic> combinedData = {};

    for (var entry in categoryBreakdown.entries) {
      combinedData[entry.key] = {
        'actual': entry.value,
        'budget': 0.0,
        'variance': -entry.value, 
        'variancePercentage': 0.0,
        'isOverBudget': true,
        'hasBudget': false,
      };
    }

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
                color: context.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.borderColor),
              ),
              child: Builder(
                builder: (context) {
                  final sortedEntries = combinedData.entries
                      .where((entry) => _toDouble(entry.value['actual']) > 0)
                      .toList();
                  
                  sortedEntries.sort((a, b) => _toDouble(b.value['actual'])
                      .compareTo(_toDouble(a.value['actual'])));

                  return combinedData.isEmpty
                      ? _buildEmptyState("No transaction data available")
                      : Column(
                          children: [
                            _buildBudgetVarianceHeader(),
                            const SizedBox(height: 16),
                            ...sortedEntries.map((entry) {
                              final categoryData = entry.value;
                              
                              // TYPE-SAFE CASTING
                              final budget = _toDouble(categoryData['budget']);
                              final actual = _toDouble(categoryData['actual']);
                              final variance = _toDouble(categoryData['variance']);
                              final variancePercentage = _toDouble(categoryData['variancePercentage']);
                              final isOverBudget = categoryData['isOverBudget'] as bool? ?? false;
                              final hasBudget = categoryData['hasBudget'] as bool? ?? false;

                              return _buildBudgetVarianceRow(
                                _getCategoryDisplayName(entry.key),
                                budget,
                                actual,
                                variance,
                                variancePercentage,
                                isOverBudget,
                                hasBudget,
                              );
                            }),
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
                color: context.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.borderColor),
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
                                    color: context.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _isLoadingCountry
                                        ? CurrencyFormatter.formatCompact(_toDouble(team['cost']), countryCode: '+91')
                                        : CurrencyFormatter.formatByCountryCompact(
                                            _toDouble(team['cost']),
                                            _userCountryCode,
                                          ),
                                    style: GoogleFonts.inter(
                                      color: context.textPrimary,
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
                                        color: context.cardSecondaryBackground,
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
                                              ? context.textPrimary
                                              : context.borderSubtle,
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

  String _formatCurrencyForForecast(double amount) {
    return _isLoadingCountry
        ? CurrencyFormatter.formatCompact(amount, countryCode: '+91')
        : CurrencyFormatter.formatByCountryCompact(amount, _userCountryCode);
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
                color: context.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.borderColor),
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

      dynamic budgetData = team['monthlyBudget'];
      double budget = 0.0;

      if (budgetData != null) {
        if (budgetData is double) {
          budget = budgetData;
        } else if (budgetData is int) {
          budget = budgetData.toDouble();
        } else if (budgetData is String) {
          String budgetStr = budgetData.replaceAll(RegExp(r'[^\d.]'), '');
          budget = double.tryParse(budgetStr) ?? 0.0;
        }
      }

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
            data['team']?.toString() ?? 'Unknown',
            _formatCurrencyForForecast(_toDouble(data['budget'])),
            _formatCurrencyForForecast(_toDouble(data['actual'])),
            data['isOver'] == true
                ? "${_formatCurrencyForForecast(_toDouble(data['variance']).abs())} over"
                : "${_formatCurrencyForForecast(_toDouble(data['variance']).abs())} under",
            false,
          ),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: context.borderColor),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Total Budget",
              style: GoogleFonts.inter(
                color: context.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _formatCurrencyForForecast(totalBudget),
                  style: GoogleFonts.inter(
                    color: context.textSecondary,
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
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _formatCurrencyForForecast(totalActual),
                  style: GoogleFonts.inter(
                    color: context.textPrimary,
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
                color: context.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
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
                color: isHeader ? context.textPrimary : context.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                budget,
                textAlign: TextAlign.end,
                style: GoogleFonts.inter(
                  color: isHeader ? context.textPrimary : context.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                actual,
                textAlign: TextAlign.end,
                style: GoogleFonts.inter(
                  color: isHeader ? context.textPrimary : context.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
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
                      ? context.textPrimary
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

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Text(
            "Failed to load financial data",
            style: GoogleFonts.inter(
              color: context.textSecondary,
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
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: _buildEmptyState("Failed to load data"),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
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
                          context.borderSubtle,
                          context.borderColor,
                          context.borderColorStrong,
                          context.borderColor,
                          context.borderSubtle,
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
                          context.borderSubtle,
                          context.borderColor,
                          context.borderColorStrong,
                          context.borderColor,
                          context.borderSubtle,
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
                      context.borderSubtle,
                      context.borderColor,
                      context.borderColorStrong,
                      context.borderColor,
                      context.borderSubtle,
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
                  color: context.cardSecondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.borderSubtle,
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
                              context.borderSubtle,
                              context.borderColor,
                              context.borderColorStrong,
                              context.borderColor,
                              context.borderSubtle,
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
                              context.borderSubtle,
                              context.borderColor,
                              context.borderColorStrong,
                              context.borderColor,
                              context.borderSubtle,
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
                context.borderSubtle,
                context.borderColor,
                context.borderColorStrong,
                context.borderColor,
                context.borderSubtle,
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
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
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
              color: context.textTertiary,
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
              color: context.textTertiary,
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
              color: context.textTertiary,
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
              color: context.textTertiary,
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
                    color: context.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!hasBudget)
                  Text(
                    'No budget set',
                    style: GoogleFonts.inter(
                      color: context.textTertiary,
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
                color: hasBudget ? context.textTertiary : context.borderSubtle,
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
                color: actual > 0 ? context.textPrimary : context.textTertiary,
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