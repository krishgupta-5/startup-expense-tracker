import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Required for FontFeature
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:developer';

import '../../../services/financial_calculator.dart';
import 'runway_estimation_screen.dart';
import 'funds_overview_screen.dart';
import 'monthly_burn_screen.dart';
import '../../../services/financial_data_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? runwayValue;
  bool isLoading = true;
  String? errorMessage;
  String? totalFundsAvailable;
  String? monthlyBurn;
  List<Map<String, dynamic>> allExpenses = [];

  Map<String, dynamic>? _financialData;
  bool _isPieChartLoading = true;
  bool _isMonthlyBurnLoading = true;
  bool _isFundsLoading = true;

  List<Map<String, dynamic>> _trendData = [];
  bool _isTrendLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    _fetchRunwayData();
    fetchTotalFundsAvailable();
    fetchMonthlyBurn();
    _loadFinancialDataForPieChart();
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

  Widget _buildRunwayDisplay(String runwayValue) {
    final runway = double.tryParse(runwayValue) ?? 0;

    // Show empty state if 0 or no data
    if (runway <= 0) {
      return Text(
        "--",
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 56,
          fontWeight: FontWeight.w400,
          height: 1.0,
          letterSpacing: -2,
        ),
      );
    }

    final wholeMonths = runway.floor();
    final remainingDays = ((runway - wholeMonths) * 30).round();

    if (remainingDays == 0) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "$wholeMonths",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w400,
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
            TextSpan(
              text: " months",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w400,
                height: 1.0,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      );
    } else {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "$wholeMonths",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w400,
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
            TextSpan(
              text: " M ",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w400,
                height: 1.0,
                letterSpacing: -1,
              ),
            ),
            TextSpan(
              text: "$remainingDays",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w400,
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
            TextSpan(
              text: " D",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w400,
                height: 1.0,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      );
    }
  }

  String _getRunwaySubtitle(String runwayValue) {
    if (double.tryParse(runwayValue) == 0 || runwayValue == "0") {
      return "Add expenses to calculate";
    }
    return "remaining";
  }

  double _calculateRunwayProgress() {
    if (runwayValue == null || errorMessage != null) return 0.0;
    final runway = double.tryParse(runwayValue!) ?? 0;
    if (runway == 0) return 0.0;

    const double criticalThreshold = 3;
    const double warningThreshold = 6;
    const double safeThreshold = 12;

    if (runway <= criticalThreshold) {
      return (runway / criticalThreshold) * 0.33;
    } else if (runway <= warningThreshold) {
      return 0.33 +
          ((runway - criticalThreshold) /
                  (warningThreshold - criticalThreshold)) *
              0.33;
    } else if (runway <= safeThreshold) {
      return 0.66 +
          ((runway - warningThreshold) / (safeThreshold - warningThreshold)) *
              0.34;
    } else {
      return 1.0;
    }
  }

  HealthStatus _calculateHealthStatus() {
    if (isLoading) return HealthStatus.unknown;
    if (runwayValue == null || errorMessage != null)
      return HealthStatus.unknown;

    final runway = double.tryParse(runwayValue!) ?? 0;
    if (runway <= 0) return HealthStatus.unknown;
    if (runway <= 3) return HealthStatus.critical;
    if (runway <= 6) return HealthStatus.warning;
    return HealthStatus.safe;
  }

  Future<void> _fetchRunwayData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted)
          setState(() {
            errorMessage = "User not authenticated";
            isLoading = false;
          });
        return;
      }

      final docSnapshot = await FirebaseFirestore.instance
          .collection("companies")
          .doc(user.uid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final runwayFromFirebase = data["Runway"]?.toString() ?? "0";

        if (runwayFromFirebase != "0") {
          final runwayAmount =
              double.tryParse(runwayFromFirebase.toString()) ?? 0;
          if (mounted)
            setState(() {
              runwayValue = runwayAmount.toStringAsFixed(2);
              isLoading = false;
            });
        } else {
          if (mounted)
            setState(() {
              runwayValue = "0";
              isLoading = false;
            });
        }
      } else {
        if (mounted)
          setState(() {
            errorMessage = "No company data found";
            isLoading = false;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          errorMessage = "Failed to load runway data";
          isLoading = false;
        });
    }
  }

  Future<void> fetchTotalFundsAvailable() async {
    if (!mounted) return;
    setState(() => _isFundsLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isFundsLoading = false);
        return;
      }

      final docSnapshot = await FirebaseFirestore.instance
          .collection("companies")
          .doc(user.uid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final funding = data["Funding"] ?? data["funding"] ?? data["FUNDING"];
        final totalExpenses =
            data["totalExpenses"] ?? data["total_expenses"] ?? "0";

        if (funding != null) {
          final fundingAmount = double.tryParse(funding.toString()) ?? 0;
          final totalExpensesAmount =
              double.tryParse(totalExpenses.toString()) ?? 0;
          final availableFundsNum = fundingAmount - totalExpensesAmount;

          if (mounted) {
            setState(() {
              String formattedFunds = availableFundsNum
                  .toStringAsFixed(0)
                  .replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (match) => '${match[1]},',
                  );
              totalFundsAvailable = "₹$formattedFunds";
              _isFundsLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isFundsLoading = false);
        }
      } else {
        if (mounted) setState(() => _isFundsLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isFundsLoading = false);
    }
  }

  Future<void> fetchMonthlyBurn() async {
    if (!mounted) return;
    setState(() => _isMonthlyBurnLoading = true);
    try {
      await _fetchAllExpenses();

      // Convert expenses to format expected by FinancialCalculator
      final expensesForCalculation = allExpenses
          .map(
            (expense) => {
              'amount': expense['amount'] as double,
              'date': expense['date'],
              'type':
                  'one_time', // Default type since original data doesn't specify
            },
          )
          .toList();

      final currentMonthBurnAmount = FinancialCalculator.currentMonthBurn(
        expensesForCalculation,
      );

      if (mounted) {
        setState(() {
          monthlyBurn = currentMonthBurnAmount > 0
              ? "₹${currentMonthBurnAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}"
              : null;
          _isMonthlyBurnLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          monthlyBurn = null;
          _isMonthlyBurnLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAllExpenses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .orderBy('Date', descending: true)
          .limit(100)
          .get();

      if (mounted) {
        setState(() {
          allExpenses = querySnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'title': data['Title'] ?? 'Unnamed Expense',
              'amount': (data['Amount'] as num?)?.toDouble() ?? 0.0,
              'category': data['Category'] ?? 'General',
              'date': data['Date'],
            };
          }).toList();
        });
      }
    } catch (e) {
      log("Error fetching expenses: $e");
    }
  }

  Future<void> _loadFinancialDataForPieChart() async {
    if (!mounted) return;
    setState(() => _isPieChartLoading = true);
    try {
      final financialData = await FinancialDataService.getMonthlyBurnData();
      if (mounted) {
        setState(() {
          _financialData = financialData;
          final rawTrend = financialData['trendData'] as List? ?? [];
          _trendData = List<Map<String, dynamic>>.from(rawTrend);
          _isPieChartLoading = false;
          _isTrendLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPieChartLoading = false;
          _isTrendLoading = false;
        });
      }
    }
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

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    HealthStatus currentHealth = _calculateHealthStatus();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMinimalHeader(context),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RunwayEstimationScreen(),
                  ),
                ),
                child: _buildFlatRunwayCard(currentHealth),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FundsOverviewScreen(),
                        ),
                      ),
                      child: _buildFlatMetricCard(
                        label: "Available Funds",
                        value: totalFundsAvailable,
                        icon: Icons.account_balance_wallet_outlined,
                        isLoading: _isFundsLoading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MonthlyBurnScreen(),
                        ),
                      ),
                      child: _buildFlatMetricCard(
                        label: "Monthly Burn",
                        value: monthlyBurn,
                        icon: Icons.local_fire_department_outlined,
                        isBurn: true,
                        isLoading: _isMonthlyBurnLoading,
                        emptyLabel: "₹0", // Clean empty label
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle("Burn Trend"),
                  _buildViewAllButton(context),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MonthlyBurnScreen()),
                ),
                child: _buildTrendChart(),
              ),
              const SizedBox(height: 40),
              _buildSectionTitle("Expense Breakdown"),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MonthlyBurnScreen()),
                ),
                child: _buildPieChartBreakdown(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Overview",
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Startup Health",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => widget.onNavigateToTab?.call(4),
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.person, color: Colors.white38),
          ),
        ),
      ],
    );
  }

  Widget _buildFlatRunwayCard(HealthStatus status) {
    Color statusColor;
    String statusText;
    switch (status) {
      case HealthStatus.safe:
        statusColor = const Color(0xFF30D158);
        statusText = "SAFE";
        break;
      case HealthStatus.warning:
        statusColor = const Color(0xFFFF9F0A);
        statusText = "WARNING";
        break;
      case HealthStatus.critical:
        statusColor = const Color(0xFFFF453A);
        statusText = "CRITICAL";
        break;
      case HealthStatus.unknown:
        statusColor = Colors.white54;
        statusText = "NO DATA";
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Est. Runway",
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _loadAllData,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: GoogleFonts.inter(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isLoading)
                Text(
                  "--",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w400,
                    height: 1.0,
                    letterSpacing: -2,
                  ),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _buildRunwayDisplay(runwayValue ?? "0"),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRunwaySubtitle(runwayValue ?? "0"),
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
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _calculateRunwayProgress(),
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatMetricCard({
    required String label,
    String? value,
    required IconData icon,
    bool isBurn = false,
    bool isLoading = false,
    String? emptyLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(height: 24),
          if (isLoading)
            AnimatedOpacity(
              opacity: 0.3,
              duration: const Duration(milliseconds: 600),
              child: Container(
                width: 80,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
          else
            Text(
              value ?? emptyLabel ?? "₹0",
              style: GoogleFonts.inter(
                color: value != null ? Colors.white : Colors.white38,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildTrendChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: _isTrendLoading
          ? const SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white38,
                ),
              ),
            )
          : _trendData.isEmpty
          ? _buildEmptyState("Not enough data for trend analysis")
          : SizedBox(
              height: 160,
              child: Builder(
                builder: (context) {
                  final display = _trendData.length > 6
                      ? _trendData.sublist(_trendData.length - 6)
                      : _trendData;
                  final maxAmount = display.isEmpty
                      ? 1.0
                      : display
                            .map((d) => (d['amount'] as num).toDouble())
                            .reduce((a, b) => a > b ? a : b);

                  return Row(
                    mainAxisAlignment: display.length <= 3
                        ? MainAxisAlignment.spaceEvenly
                        : MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: display.map((data) {
                      final amount = (data['amount'] as num).toDouble();
                      final pct = maxAmount > 0 ? amount / maxAmount : 0.0;
                      return _buildFlatBar(
                        data['month'] as String,
                        pct,
                        isActive: data['isCurrentMonth'] as bool? ?? false,
                      );
                    }).toList(),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildFlatBar(String label, double pct, {bool isActive = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 36,
          height: 120 * pct,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : const Color(0xFF1F1F22),
            borderRadius: BorderRadius.circular(6),
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

  Widget _buildPieChartBreakdown() {
    if (_isPieChartLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white38,
          ),
        ),
      );
    }

    final categoryBreakdown =
        _financialData?['categoryBreakdown'] as Map<String, double>? ?? {};
    final totalExpenses = _financialData?['totalExpenses'] as double? ?? 0;

    // REMOVED DUMMY DATA. If empty, show sleek empty state.
    if (categoryBreakdown.isEmpty || totalExpenses == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: _buildEmptyState("No expense data available"),
      );
    }

    final categories = categoryBreakdown.map(
      (key, value) =>
          MapEntry(key, {'amount': value, 'color': _getCategoryColor(key)}),
    );

    final expenseData = categories.entries.map((entry) {
      final amount = entry.value['amount'] as double;
      final percentage = FinancialCalculator.calculatePercentage(
        amount: amount,
        total: totalExpenses,
      );
      return {
        'category': _capitalizeFirstLetter(entry.key),
        'amount': amount,
        'percentage': percentage,
        'color': entry.value['color'] as Color,
      };
    }).toList();

    expenseData.sort(
      (a, b) => (b['percentage'] as int).compareTo(a['percentage'] as int),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      centerSpaceColor: Colors.transparent,
                      sections: expenseData.map((data) {
                        return PieChartSectionData(
                          color: data['color'] as Color,
                          value: (data['percentage'] as int).toDouble(),
                          title: '',
                          radius: 16,
                          showTitle: false,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: expenseData.map((data) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: data['color'] as Color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              data['category'] as String,
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${data['percentage']}%',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [
                                const FontFeature.tabularFigures(),
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
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Monthly Expenses',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '₹${totalExpenses.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MonthlyBurnScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Text(
              "FULL ANALYSIS",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 12),
          ],
        ),
      ),
    );
  }
}

enum HealthStatus { safe, warning, critical, unknown }
