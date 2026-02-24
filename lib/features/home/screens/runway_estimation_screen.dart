// Required for FontFeature
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class RunwayEstimationScreen extends StatefulWidget {
  const RunwayEstimationScreen({super.key});

  @override
  State<RunwayEstimationScreen> createState() => _RunwayEstimationScreenState();
}

class _RunwayEstimationScreenState extends State<RunwayEstimationScreen> {
  // Data variables
  double? runwayMonths;
  String? currentBalance;
  String? monthlyBurn;
  String? netBurn;
  String? zeroCashDate;
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> monthlyProjections = [];
  List<Map<String, dynamic>> allExpenses = [];

  @override
  void initState() {
    super.initState();
    _fetchRunwayData();
    _fetchAllExpenses();
  }

  Future<void> _fetchRunwayData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
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

        // Get runway from Firebase
        final runwayFromFirebase = data["Runway"]?.toString() ?? "0";
        final funding = data["Funding"] ?? data["funding"] ?? data["FUNDING"];
        final totalExpenses =
            data["totalExpenses"] ?? data["total_expenses"] ?? "0";

        if (runwayFromFirebase != "0" && funding != null) {
          final runwayAmount =
              double.tryParse(runwayFromFirebase.toString()) ?? 0;
          final fundingAmount = double.tryParse(funding.toString()) ?? 0;
          final totalExpensesAmount =
              double.tryParse(totalExpenses.toString()) ?? 0;
          final availableBalance = fundingAmount - totalExpensesAmount;

          // Calculate monthly burn (total expenses per month)
          final monthlyBurnAmount = totalExpensesAmount > 0
              ? totalExpensesAmount
              : 42500; // Default fallback

          // Calculate net burn (monthly burn minus any revenue)
          final netBurnAmount = monthlyBurnAmount; // Simplified for now

          // Calculate zero cash date
          final calculatedZeroCashDate = _calculateZeroCashDate(runwayAmount);

          // Generate monthly projections
          final projections = _generateMonthlyProjections(
            availableBalance,
            monthlyBurnAmount.toDouble(),
          );

          setState(() {
            runwayMonths = runwayAmount;
            currentBalance =
                "₹${availableBalance.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}";
            monthlyBurn =
                "₹${monthlyBurnAmount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}";
            netBurn =
                "₹${netBurnAmount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}";
            zeroCashDate = calculatedZeroCashDate;
            monthlyProjections = projections;
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = "No runway data found";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "No company data found";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed to load runway data: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _fetchAllExpenses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .orderBy('Date', descending: true)
          .get();

      setState(() {
        allExpenses = expensesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['Title'] ?? 'Unnamed Expense',
            'amount': (data['Amount'] as num).toDouble(),
            'category': data['Category'] ?? 'General',
            'date': data['Date'],
            'description': data['Description'] ?? '',
            'type': data['Type'] ?? 'one_time',
          };
        }).toList();
      });
    } catch (e) {
      print("Error fetching expenses: $e");
    }
  }

  String _calculateZeroCashDate(double runwayMonths) {
    final now = DateTime.now();
    final zeroCashDateTime = now.add(
      Duration(days: (runwayMonths * 30.44).round()),
    ); // Average month length

    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return "${months[zeroCashDateTime.month - 1]} ${zeroCashDateTime.day}, ${zeroCashDateTime.year}";
  }

  List<Map<String, dynamic>> _generateMonthlyProjections(
    double currentBalance,
    double monthlyBurn,
  ) {
    final projections = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 1; i <= 6; i++) {
      final futureDate = DateTime(now.year, now.month + i, 15);
      final projectedBalance = currentBalance - (monthlyBurn * i);
      final remainingRunway = projectedBalance > 0
          ? projectedBalance / monthlyBurn
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
        'balance':
            "₹${projectedBalance.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}",
        'monthsLeft': remainingRunway.toStringAsFixed(1),
      });
    }

    return projections;
  }

  String _getHealthStatus() {
    if (runwayMonths == null) return "UNKNOWN";

    if (runwayMonths! <= 3) {
      return "CRITICAL";
    } else if (runwayMonths! <= 6) {
      return "WARNING";
    } else {
      return "SAFE";
    }
  }

  Color _getHealthStatusColor() {
    final status = _getHealthStatus();
    switch (status) {
      case "CRITICAL":
        return const Color(0xFFFF453A);
      case "WARNING":
        return const Color(0xFFFF9F0A);
      case "SAFE":
        return const Color(0xFF30D158);
      default:
        return Colors.white38;
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
                // Header
                _buildHeader(context),

                const SizedBox(height: 32),

                // Main Runway Card
                _buildMainRunwayCard(),

                const SizedBox(height: 32),

                // Financial Metrics Grid
                _buildFinancialMetricsGrid(),

                const SizedBox(height: 32),

                // Monthly Projection Chart
                _buildMonthlyProjectionSection(),

                const SizedBox(height: 32),

                // Risk Factors
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
                child: Text(
                  _getHealthStatus(),
                  style: GoogleFonts.inter(
                    color: _getHealthStatusColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _fetchRunwayData,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
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
          if (isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                "Loading...",
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 40,
                  fontWeight: FontWeight.w300,
                  height: 1.0,
                  letterSpacing: -3,
                ),
              ),
            )
          else if (errorMessage != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "!",
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF453A),
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                    height: 1.0,
                    letterSpacing: -3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      errorMessage!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF453A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  runwayMonths?.toStringAsFixed(1) ?? "0.0",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                    height: 1.0,
                    letterSpacing: -3,
                  ),
                ),
                const SizedBox(width: 16),
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
                  zeroCashDate ?? "Calculating...",
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
        Text(
          "Financial Health",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        // Row 1: Balance and Burn
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                "Current Balance",
                currentBalance ?? "Loading...",
                Icons.account_balance_wallet_outlined,
                const Color(0xFF30D158),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                "Monthly Burn",
                monthlyBurn ?? "Loading...",
                Icons.local_fire_department_outlined,
                const Color(0xFFFF9F0A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Row 2: ONLY Net Burn (Monthly Revenue removed)
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                "Net Burn",
                netBurn ?? "Loading...",
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
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
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

  Widget _buildMonthlyProjectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Monthly Projection",
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: isLoading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      "Loading projections...",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : monthlyProjections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      "No projections available",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
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
                            _buildDivider(),
                        ],
                      );
                    }).toList(),
                  ],
                ),
        ),
      ],
    );
  }

  // Helper for subtle divider
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(0.04),
    );
  }

  Widget _buildProjectionRow(String month, String balance, String monthsLeft) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Date
          SizedBox(
            width: 80,
            child: Text(
              month,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 2. Balance
          Text(
            balance,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          // 3. Months (Fixed Alignment: In Front/One line)
          SizedBox(
            width: 80,
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
                  "mo", // Shortened to 'mo' to ensure it stays on one line
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
    // Calculate risk factors based on actual expense data
    final List<Map<String, dynamic>> riskFactors = _calculateRiskFactors();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Risk Factors",
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: riskFactors.isEmpty
              ? Center(
                  child: Text(
                    "No risk factors identified",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
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

    if (allExpenses.isEmpty) {
      return risks;
    }

    // Calculate total expenses by category
    final Map<String, double> categoryTotals = {};
    for (var expense in allExpenses) {
      final category = expense['category'] as String;
      final amount = expense['amount'] as double;
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }

    // Check for high marketing spend
    final marketingSpend = categoryTotals['Marketing'] ?? 0;
    if (marketingSpend > 5000) {
      risks.add({
        'title': 'High Marketing Spend',
        'description': 'Marketing costs increased significantly this quarter',
        'color': const Color(0xFFFF9F0A),
      });
    }

    // Check for high operational costs
    final operationalSpend =
        (categoryTotals['Operations'] ?? 0) +
        (categoryTotals['Infrastructure'] ?? 0);
    if (operationalSpend > 10000) {
      risks.add({
        'title': 'High Operational Costs',
        'description': 'Infrastructure and operational costs are above average',
        'color': const Color(0xFFFF9F0A),
      });
    }

    // Check runway status
    if (runwayMonths != null && runwayMonths! < 6) {
      risks.add({
        'title': 'Limited Runway',
        'description': 'Current runway is less than 6 months',
        'color': const Color(0xFFFF453A),
      });
    }

    // Add positive factors
    if (runwayMonths != null && runwayMonths! > 12) {
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
