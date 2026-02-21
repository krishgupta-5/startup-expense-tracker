import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
// Required for FontFeature
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

// --- Screen Imports (Restored) ---
import 'runway_estimation_screen.dart';
import 'funds_overview_screen.dart';
import 'monthly_burn_screen.dart';

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
  Timer? _timer;
  String? totalFundsAvailable;

  @override
  void initState() {
    super.initState();
    _fetchRunwayData();
    fetchTotalFundsAvailable();
    _startDailyDecrement();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startDailyDecrement() {
    // Update runway every minute for demo purposes (change to 24h for production)
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (runwayValue != null && errorMessage == null) {
        _decrementRunway();
      }
    });
  }

  void _decrementRunway() {
    final currentRunway = double.tryParse(runwayValue ?? "0") ?? 0;
    if (currentRunway > 0) {
      // Decrease by 1/30 of a month (approximately 1 day)
      final newRunway = currentRunway - (1 / 30);
      setState(() {
        runwayValue = newRunway.toStringAsFixed(2);
      });
    }
  }

  Widget _buildRunwayDisplay(String runwayValue) {
    final runway = double.tryParse(runwayValue) ?? 0;
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
    return "";
  }

  double _calculateRunwayProgress() {
    if (runwayValue == null || errorMessage != null) return 0.0;

    final runway = double.tryParse(runwayValue!) ?? 0;

    // Define runway thresholds (in months)
    const double criticalThreshold = 3; // 3 months or less = critical
    const double warningThreshold = 6; // 6 months or less = warning
    const double safeThreshold = 12; // 12 months or more = safe

    if (runway <= criticalThreshold) {
      // Critical: 0-33% progress
      return (runway / criticalThreshold) * 0.33;
    } else if (runway <= warningThreshold) {
      // Warning: 33-66% progress
      return 0.33 +
          ((runway - criticalThreshold) /
                  (warningThreshold - criticalThreshold)) *
              0.33;
    } else if (runway <= safeThreshold) {
      // Safe: 66-100% progress
      return 0.66 +
          ((runway - warningThreshold) / (safeThreshold - warningThreshold)) *
              0.34;
    } else {
      // Very safe: cap at 100%
      return 1.0;
    }
  }

  HealthStatus _calculateHealthStatus() {
    if (runwayValue == null || errorMessage != null)
      return HealthStatus.critical;

    final runway = double.tryParse(runwayValue!) ?? 0;

    if (runway <= 3) {
      return HealthStatus.critical;
    } else if (runway <= 6) {
      return HealthStatus.warning;
    } else {
      return HealthStatus.safe;
    }
  }

  Future<void> _fetchRunwayData() async {
    try {
      print("DEBUG: Starting runway data fetch...");
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("DEBUG: No authenticated user found");
        setState(() {
          errorMessage = "User not authenticated";
          isLoading = false;
        });
        return;
      }

      print("DEBUG: User authenticated with UID: ${user.uid}");

      final docSnapshot = await FirebaseFirestore.instance
          .collection("companies")
          .doc(user.uid)
          .get();

      print("DEBUG: Document exists: ${docSnapshot.exists}");

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        print("DEBUG: Document data: $data");
        print("DEBUG: Available keys: ${data.keys.toList()}");

        // Try different possible field names
        final runway =
            data["Runway"] ??
            data["runway"] ??
            data["RUNWAY"] ??
            data["runway_months"];
        print("DEBUG: Runway value: $runway");

        if (runway == null) {
          print("DEBUG: No runway field found in document");
          setState(() {
            errorMessage = "Runway field not found in document";
            isLoading = false;
          });
        } else {
          setState(() {
            runwayValue = runway.toString();
            isLoading = false;
          });
          print("DEBUG: Set runwayValue to: ${runwayValue}");
        }
      } else {
        print("DEBUG: No document found or document is empty");
        setState(() {
          errorMessage = "No runway data found";
          isLoading = false;
        });
      }
    } catch (e) {
      print("DEBUG: Error fetching runway data: $e");
      setState(() {
        errorMessage = "Failed to load runway data: $e";
        isLoading = false;
      });
    }
  }

  Future<void> fetchTotalFundsAvailable() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("DEBUG: No authenticated user found for funds fetch");
        return;
      }

      print("DEBUG: Starting funds data fetch...");

      final docSnapshot = await FirebaseFirestore.instance
          .collection("companies")
          .doc(user.uid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        print("DEBUG: Funds document data: $data");

        // Use the correct field name "Funding" instead of "Total Funds"
        final funding = data["Funding"] ?? data["funding"] ?? data["FUNDING"];
        print("DEBUG: Funding value: $funding");

        if (funding != null) {
          setState(() {
            // Format as currency with proper formatting
            final fundingAmount = double.tryParse(funding.toString()) ?? 0;
            totalFundsAvailable =
                "₹${(fundingAmount / 100000).toStringAsFixed(1)}L";
          });
          print("DEBUG: Set totalFundsAvailable to: $totalFundsAvailable");
        } else {
          print("DEBUG: No funding field found");
        }
      }
    } catch (e) {
      print("DEBUG: Error fetching funds data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate health status based on runway value
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
              // 1. Header (Minimal)
              _buildMinimalHeader(context),

              const SizedBox(height: 32),

              // 2. Hero Card (Runway) - Flat Style
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RunwayEstimationScreen(),
                    ),
                  );
                },
                child: _buildFlatRunwayCard(currentHealth),
              ),

              const SizedBox(height: 16),

              // 3. Metrics Grid (Funds & Burn) - Flat Style
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FundsOverviewScreen(),
                          ),
                        );
                      },
                      child: _buildFlatMetricCard(
                        label: "Total Funds",
                        value: totalFundsAvailable ?? "",
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MonthlyBurnScreen(),
                          ),
                        );
                      },
                      child: _buildFlatMetricCard(
                        label: "Monthly Burn",
                        value: "\$42.5k",
                        icon: Icons.local_fire_department_outlined,
                        isBurn: true,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 4. Trend Chart (Corrected to show Bars)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle("Burn Trend"),
                  _buildViewAllButton(context),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                // Drills down to Monthly Burn Screen for more detail
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MonthlyBurnScreen(),
                    ),
                  );
                },
                child: _buildTrendChart(),
              ),

              const SizedBox(height: 40),

              // 6. Breakdown (Pie Chart)
              _buildSectionTitle("Expense Breakdown"),
              const SizedBox(height: 20),
              GestureDetector(
                // Drills down to Monthly Burn Screen for more detail
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MonthlyBurnScreen(),
                    ),
                  );
                },
                child: _buildPieChartBreakdown(),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

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
        // Minimal Profile Placeholder
        GestureDetector(
          onTap: () {
            // Navigate to settings tab (index 4) in bottom navigation
            widget.onNavigateToTab?.call(4);
          },
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
        statusText = "Safe";
        break;
      case HealthStatus.warning:
        statusColor = const Color(0xFFFF9F0A);
        statusText = "Warning";
        break;
      case HealthStatus.critical:
        statusColor = const Color(0xFFFF453A);
        statusText = "Critical";
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416), // Solid Matte Grey
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
                  // Refresh button for debugging
                  GestureDetector(
                    onTap: _fetchRunwayData,
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
                      child: Icon(
                        Icons.refresh,
                        color: Colors.white38,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tiny minimal badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
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
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
              else if (errorMessage != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "!",
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF453A),
                        fontSize: 56,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      errorMessage!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF453A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRunwayDisplay(runwayValue ?? "0"),
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
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _getRunwaySubtitle(runwayValue ?? "0"),
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Flat Progress Bar
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
    required String value,
    required IconData icon,
    bool isBurn = false,
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
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 22,
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
      child: SizedBox(
        height: 160,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildFlatBar("Jan", 0.4),
            _buildFlatBar("Feb", 0.5),
            _buildFlatBar("Mar", 0.45),
            _buildFlatBar("Apr", 0.6),
            _buildFlatBar("May", 0.55),
            _buildFlatBar("Jun", 0.8, isActive: true),
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
          width: 36, // Slightly wider for touch targets
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
    final expenseData = [
      {
        'category': 'Salaries',
        'amount': 27625,
        'percentage': 65,
        'color': const Color(0xFF30D158),
      },
      {
        'category': 'Servers',
        'amount': 8500,
        'percentage': 20,
        'color': const Color(0xFF3A4B8A),
      },
      {
        'category': 'Marketing',
        'amount': 4250,
        'percentage': 10,
        'color': const Color(0xFFFF9F0A),
      },
      {
        'category': 'Office',
        'amount': 2125,
        'percentage': 5,
        'color': const Color(0xFF00BFA5),
      },
    ];

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pie Chart
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 140, // Constrained height
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      centerSpaceColor: Colors.transparent,
                      sections: expenseData.map((data) {
                        return PieChartSectionData(
                          color: data['color'] as Color,
                          value: (data['percentage'] as int).toDouble(),
                          title: '', // Hiding title on chart for cleaner look
                          radius: 16,
                          showTitle: false,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: expenseData.map((data) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['category'] as String,
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
          // Total Footer
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
                  '\$42,500',
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MonthlyBurnScreen()),
        );
      },
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

enum HealthStatus { safe, warning, critical }
