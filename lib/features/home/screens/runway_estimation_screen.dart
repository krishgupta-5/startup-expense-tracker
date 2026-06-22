import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/financial_calculator.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/currency_preference_service.dart';
import '../../../utils/expense_expansion_helper.dart';

class RunwayEstimationScreen extends StatefulWidget {
  const RunwayEstimationScreen({super.key});

  @override
  State<RunwayEstimationScreen> createState() => RunwayEstimationScreenState();
}

class RunwayEstimationScreenState extends State<RunwayEstimationScreen> {
  // Data variables
  double? runwayMonths;
  String? currentBalance;
  String? monthlyBurn;
  String? netBurn;
  String? zeroCashDate;
  bool isLoading = true;

  List<Map<String, dynamic>> monthlyProjections = [];
  List<Map<String, dynamic>> allExpenses = [];

  String _userCountryCode = '+1'; // Default to USD

  @override
  void initState() {
    super.initState();
    // Get currency preference synchronously for instant display
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    // Listen for currency changes
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
    // Load in background for more accurate result
    _loadUserCountryCode();
    _loadData();
  }

  @override
  void dispose() {
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
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

  Future<void> _loadUserCountryCode() async {
    final currencyCode =
        await CurrencyPreferenceService.getCurrencyPreference();
    if (mounted && currencyCode != _userCountryCode) {
      setState(() {
        _userCountryCode = currencyCode;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    await _fetchAllExpenses();
    await _fetchRunwayData();
  }

  String _formatCurrency(double amount) {
    return CurrencyFormatter.formatByCountryCompact(amount, _userCountryCode);
  }

  Future<void> _fetchRunwayData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _setEmptyState();
        return;
      }

      final docSnapshot = await FirebaseFirestore.instance
          .collection("companies")
          .doc(user.uid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;

        // Get runway from Firebase
        final runwayFromFirebase = data["Runway"]?.toString() ?? "0";
        final funding = data["Funding"] ?? data["funding"] ?? data["FUNDING"];
        final runwayAmount =
            double.tryParse(runwayFromFirebase.toString()) ?? 0;
        final fundingAmount = double.tryParse(funding?.toString() ?? "0") ?? 0;
        // Compute available balance from REAL loaded expenses
        // (NOT from stale company doc field that is never written)
        final realTotalExpenses = allExpenses.fold<double>(
          0.0,
          (t, e) => t + (e['amount'] as double? ?? 0.0),
        );
        final availableBalance = fundingAmount - realTotalExpenses;

        // Calculate current month burn using FinancialCalculator with proper scaling
        // IMPORTANT: allExpenses are already expanded by ExpenseExpansionHelper,
        // so each virtual occurrence is a separate entry. We must mark them as
        // 'one_time' here so currentMonthBurn() doesn't re-apply recurring scaling.
        final expensesForCalculation = allExpenses
            .map(
              (expense) => {
                'amount': expense['amount'] as double,
                'date': expense['date'],
                'type': 'one_time', // Already expanded — no double-counting
                'recurrenceFrequency': expense['recurrenceFrequency'],
                'recurringTenureMonths': expense['recurringTenureMonths'],
              },
            )
            .toList();

        final teamMembersSnapshot = await FirebaseFirestore.instance
            .collection('members')
            .where('uid', isEqualTo: user.uid)
            .get();

        double salariesTotal = 0.0;
        for (var doc in teamMembersSnapshot.docs) {
          final data = doc.data();
          salariesTotal += (double.tryParse((data['salary'] ?? data['Salary'])?.toString() ?? '0') ?? 0.0);
        }

        final currentMonthBurnAmount = FinancialCalculator.currentMonthBurn(
          expensesForCalculation,
        );
        double actualMonthlyBurn = currentMonthBurnAmount + salariesTotal;

        if (actualMonthlyBurn == salariesTotal && allExpenses.isNotEmpty) {
          actualMonthlyBurn = _calculateAverageMonthlyBurn() + salariesTotal;
        }

        // --- NO DATA / NEW ACCOUNT GRACEFUL HANDLING ---
        if (actualMonthlyBurn == 0 || availableBalance <= 0) {
          setState(() {
            runwayMonths = availableBalance <= 0 ? 0.0 : runwayAmount;
            currentBalance = _formatCurrency(
              availableBalance < 0 ? 0 : availableBalance,
            );
            monthlyBurn = '${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0';
            netBurn = '${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0';
            zeroCashDate = availableBalance <= 0
                ? (fundingAmount == 0 ? 'Awaiting funding' : 'Funds depleted')
                : 'Add expenses to track';
            monthlyProjections = [];
            isLoading = false;
          });
          return;
        }

        // Calculate zero cash date
        final calculatedZeroCashDate = _calculateZeroCashDate(
          availableBalance / actualMonthlyBurn,
        );

        // Generate monthly projections
        final projections = _generateMonthlyProjections(
          availableBalance,
          actualMonthlyBurn,
        );

        setState(() {
          runwayMonths = availableBalance / actualMonthlyBurn;
          currentBalance = _formatCurrency(availableBalance);
          monthlyBurn = _formatCurrency(actualMonthlyBurn);
          netBurn = _formatCurrency(realTotalExpenses);
          zeroCashDate = calculatedZeroCashDate;
          monthlyProjections = projections;
          isLoading = false;
        });
      } else {
        _setEmptyState();
      }
    } catch (e) {
      debugPrint("Error fetching runway: $e");
      _setEmptyState();
    }
  }

  void _setEmptyState() {
    final zeroStr = '${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0';
    setState(() {
      runwayMonths = 0.0;
      currentBalance = zeroStr;
      monthlyBurn = zeroStr;
      netBurn = zeroStr;
      zeroCashDate = '--';
      monthlyProjections = [];
      isLoading = false;
    });
  }

  Future<void> _fetchAllExpenses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .get();

      final mappedExpenses = expensesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();

      final expanded = ExpenseExpansionHelper.expandExpenses(
        mappedExpenses,
        maxDate: DateTime.now(),
      );

      allExpenses = expanded
          .where((data) => data['isFunding'] != true)
          .map((data) {
        final amountVal = data['Amount'] ?? data['amount'];
        final amount = amountVal is num ? amountVal.toDouble() : double.tryParse(amountVal?.toString() ?? '0') ?? 0.0;
        return {
          'id': data['id'] ?? data['expenseId'] ?? '',
          'title': data['Title'] ?? 'Unnamed Expense',
          'amount': amount,
          'category': data['Category'] ?? 'General',
          'date': data['Date'] ?? data['date'],
          'description': data['Description'] ?? '',
          'type': data['Type'] ?? 'one_time',
          'recurrenceFrequency': data['recurrenceFrequency'] ?? data['loanRateType'] ?? 'monthly',
          'recurringTenureMonths': data['recurringTenureMonths'] ?? data['loanTenureMonths'],
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching expenses: $e");
    }
  }

  double _calculateAverageMonthlyBurn() {
    if (allExpenses.isEmpty) return 0;
    Map<String, double> monthlyTotals = {};

    for (var expense in allExpenses) {
      final expenseDate = expense['date'] as Timestamp?;
      if (expenseDate != null) {
        final expenseDateTime = expenseDate.toDate();
        final monthKey =
            "${expenseDateTime.year}-${expenseDateTime.month.toString().padLeft(2, '0')}";

        monthlyTotals[monthKey] =
            (monthlyTotals[monthKey] ?? 0) + (expense['amount'] as double);
      }
    }

    if (monthlyTotals.isEmpty) return 0;
    double total = monthlyTotals.values.fold(0, (sum, item) => sum + item);
    return total / monthlyTotals.length;
  }

  String _calculateZeroCashDate(double calculatedRunwayMonths) {
    if (calculatedRunwayMonths <= 0) return "Funds depleted";
    if (calculatedRunwayMonths > 120) {
      return "10+ Years"; // Cap to avoid massive dates
    }

    final now = DateTime.now();
    final zeroCashDateTime = now.add(
      Duration(days: (calculatedRunwayMonths * 30.44).round()),
    );

    final months = [
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

    return "${months[zeroCashDateTime.month - 1]} ${zeroCashDateTime.day}, ${zeroCashDateTime.year}";
  }

  List<Map<String, dynamic>> _generateMonthlyProjections(
    double balance,
    double burn,
  ) {
    final projections = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 1; i <= 6; i++) {
      final futureDate = DateTime(now.year, now.month + i, 15);
      final projectedBalance = balance - (burn * i);
      final remainingRunway = projectedBalance > 0
          ? projectedBalance / burn
          : 0;

      final months = [
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

      projections.add({
        'month': "${months[futureDate.month - 1]} ${futureDate.year}",
        'balance': projectedBalance > 0
            ? _formatCurrency(projectedBalance)
            : '${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0',
        'monthsLeft': remainingRunway > 0
            ? remainingRunway.toStringAsFixed(1)
            : "0.0",
      });

      if (projectedBalance <= 0) break; // Stop projecting if funds are 0
    }

    return projections;
  }

  String _getHealthStatus() {
    if (isLoading) return "CALCULATING";
    final zeroStr = '${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0';
    if (monthlyBurn == zeroStr && currentBalance == zeroStr) {
      return 'NO DATA';
    }
    if (monthlyBurn == zeroStr) return 'NO EXPENSES';
    if (runwayMonths == null || runwayMonths! <= 0) return "DEPLETED";

    if (runwayMonths! <= 3) return "CRITICAL";
    if (runwayMonths! <= 6) return "WARNING";
    return "SAFE";
  }

  Color _getHealthStatusColor() {
    final status = _getHealthStatus();
    switch (status) {
      case "CRITICAL":
      case "DEPLETED":
        return const Color(0xFFFF453A);
      case "WARNING":
        return const Color(0xFFFF9F0A);
      case "SAFE":
        return const Color(0xFF30D158);
      default:
        return Colors.white54;
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

  // --- MINIMAL EMPTY STATE COMPONENT ---
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

  // --- MINIMAL HINT TOAST INSTEAD OF DIALOG ---
  void _showProjectionHint() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white70, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Formula: Fund Left ÷ Monthly Expense",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF141416),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        duration: const Duration(seconds: 4),
        elevation: 0,
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
                const SizedBox(height: 32),
                _buildMainRunwayCard(),
                const SizedBox(height: 32),
                _buildFinancialMetricsGrid(),
                const SizedBox(height: 32),
                _buildMonthlyProjectionSection(),
                const SizedBox(height: 32),
                _buildRiskFactorsSection(),
                const SizedBox(height: 40),
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
              "Runway Analysis",
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Detailed Projection",
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

  Widget _buildMainRunwayCard() {
    return Container(
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
                  color: _getHealthStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _getHealthStatusColor().withValues(alpha: 0.3),
                  ),
                ),
                child: Flexible(
                  child: Text(
                    _getHealthStatus(),
                    style: GoogleFonts.inter(
                      color: _getHealthStatusColor(),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    "Last updated: Today",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _loadData,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white38,
                              ),
                            )
                          : const Icon(
                              Icons.refresh,
                              color: Colors.white38,
                              size: 16,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                // FIXED: FITTED BOX FOR LARGE NUMBERS
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isLoading
                        ? "--"
                        : (runwayMonths?.toStringAsFixed(1) ?? "0.0"),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 60, // Huge Hero text
                      fontWeight: FontWeight.w600, // Thickened slightly
                      height: 1.0,
                      letterSpacing: -3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  "months remaining",
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Zero Cash Date",
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLoading ? "--" : (zeroCashDate ?? "--"),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialMetricsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("FINANCIAL HEALTH"),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                "Current Balance",
                isLoading
                    ? '--'
                    : (currentBalance ?? '${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0'),
                Icons.account_balance_wallet_outlined,
                const Color(0xFF30D158),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                "Monthly Burn",
                isLoading
                    ? '--'
                    : (monthlyBurn ?? '${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0'),
                Icons.local_fire_department_outlined,
                const Color(0xFFFF9F0A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                "Total Burn",
                isLoading
                    ? '--'
                    : (netBurn ?? '${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0'),
                Icons.remove_circle_outline,
                const Color(0xFFFF453A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.8), size: 20),
          const SizedBox(height: 16),
          // FIXED: FITTED BOX FOR LARGE NUMBERS
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyProjectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionLabel("MONTHLY PROJECTION"),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showProjectionHint, // Triggers the sleek toast
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white60,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: isLoading
              ? _buildEmptyState("Loading projections...")
              : monthlyProjections.isEmpty
              ? _buildEmptyState("Add expenses to see projections")
              : Column(
                  children: [
                    ...monthlyProjections.map((projection) {
                      return Column(
                        children: [
                          _buildProjectionRow(
                            projection['month'],
                            projection['balance'],
                            projection['monthsLeft'],
                          ),
                          if (projection != monthlyProjections.last)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.white.withValues(alpha: 0.04),
                            ),
                        ],
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildProjectionRow(String month, String balance, String monthsLeft) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              month,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            // FIXED: FITTED BOX FOR LARGE NUMBERS
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                balance,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  monthsLeft,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "mo",
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskFactorsSection() {
    final List<Map<String, dynamic>> riskFactors = _calculateRiskFactors();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("RISK FACTORS"),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: isLoading
              ? _buildEmptyState("Analyzing data...")
              : riskFactors.isEmpty
              ? _buildEmptyState("Not enough data to analyze risk factors")
              : Column(
                  children: riskFactors.map((risk) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _buildRiskItem(
                        risk['title'],
                        risk['description'],
                        risk['color'],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _calculateRiskFactors() {
    final List<Map<String, dynamic>> risks = [];
    if (allExpenses.isEmpty || runwayMonths == null || runwayMonths! <= 0) {
      return risks;
    }

    final Map<String, double> categoryTotals = {};
    for (var expense in allExpenses) {
      final category = expense['category'] as String;
      final amount = expense['amount'] as double;
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }

    if ((categoryTotals['Marketing'] ?? 0) > 5000) {
      risks.add({
        'title': 'High Marketing Spend',
        'description': 'Marketing costs increased significantly this quarter',
        'color': const Color(0xFFFF9F0A),
      });
    }

    if (runwayMonths! < 6) {
      risks.add({
        'title': 'Limited Runway',
        'description': 'Current runway is less than 6 months',
        'color': const Color(0xFFFF453A),
      });
    } else if (runwayMonths! >= 6 && runwayMonths! <= 12) {
      risks.add({
        'title': 'Moderate Runway',
        'description': 'Current runway is between 6-12 months',
        'color': const Color(0xFFFF9F0A),
      });
    } else if (runwayMonths! > 12) {
      risks.add({
        'title': 'Healthy Runway',
        'description': 'Current runway extends beyond 12 months',
        'color': const Color(0xFF30D158),
      });
    }

    return risks;
  }

  Widget _buildRiskItem(String title, String description, Color riskColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
