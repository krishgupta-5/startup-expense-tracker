import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Required for FontFeature
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer';

import 'runway_estimation_screen.dart';
import 'funds_overview_screen.dart';
import 'monthly_burn_screen.dart';
import '../../../services/financial_data_service.dart';
import '../../../services/financial_calculator.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/currency_preference_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Cache for Telegram photos to avoid repeated fetching
  static final Map<String, String> _telegramPhotoCache = {};

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
    // Load in background for more accurate result
    _loadUserCountryCode();
    _loadAllData();
    // Create AI collection for existing users
    _createAIData();
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

  // Telegram photo fetching methods with caching
  Future<String> getTelegramImageUrl(String fileId) async {
    // Check cache first
    if (_telegramPhotoCache.containsKey(fileId)) {
      return _telegramPhotoCache[fileId]!;
    }

    try {
      await dotenv.load(fileName: ".env.local");
      final botToken = dotenv.env['TELEGRAM_BOT_TOKEN'];

      if (botToken == null) {
        throw Exception('Telegram bot token not found in environment');
      }

      final res = await http.get(
        Uri.parse(
          "https://api.telegram.org/bot$botToken/getFile?file_id=$fileId",
        ),
      );

      final data = jsonDecode(res.body);
      final path = data['result']['file_path'];

      final imageUrl = "https://api.telegram.org/file/bot$botToken/$path";

      // Cache the result
      _telegramPhotoCache[fileId] = imageUrl;

      return imageUrl;
    } catch (e) {
      debugPrint('Error getting Telegram image URL: $e');
      rethrow;
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

  Future<void> _loadAllData() async {
    await _fetchRunwayData();
    await fetchTotalFundsAvailable();
    await fetchMonthlyBurn();
    await _loadFinancialDataForPieChart();
  }

  Future<void> _createAIData() async {
    // AI data sync is now handled after login/signup for better performance
    // This method is kept for compatibility but no longer syncs data
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

  // --- PROFILE AVATAR METHODS ---

  // Build profile avatar with Telegram photo support
  Widget _buildProfileAvatar(String? profileImageFileId) {
    if (profileImageFileId != null && profileImageFileId.isNotEmpty) {
      // Show uploaded profile image
      return FutureBuilder<String>(
        future: getTelegramImageUrl(profileImageFileId),
        builder: (context, snapshot) {
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: snapshot.hasData
                  ? Image.network(
                      snapshot.data!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar();
                      },
                    )
                  : _buildDefaultAvatar(),
            ),
          );
        },
      );
    }

    // Show default avatar
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        color: const Color(0xFF141416),
      ),
      child: const Icon(Icons.person, size: 20, color: Colors.white),
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

  Widget _buildRunwayDisplay(String runwayValue) {
    final runway = double.tryParse(runwayValue) ?? 0;

    // Show empty state if 0 or no data
    if (runway <= 0) {
      return Text(
        "--",
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 56,
          fontWeight: FontWeight.w600, // Upgraded weight
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
                fontWeight: FontWeight.w600, // Upgraded weight
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
            TextSpan(
              text: " months",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w600, // Upgraded weight
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
                fontWeight: FontWeight.w600, // Upgraded weight
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
            TextSpan(
              text: " M ",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w600, // Upgraded weight
                height: 1.0,
                letterSpacing: -1,
              ),
            ),
            TextSpan(
              text: "$remainingDays",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w600, // Upgraded weight
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
            TextSpan(
              text: " D",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w600, // Upgraded weight
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
    if (runwayValue == null || errorMessage != null) {
      return HealthStatus.unknown;
    }

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
        if (mounted) {
          setState(() {
            errorMessage = "User not authenticated";
            isLoading = false;
          });
        }
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
          if (mounted) {
            setState(() {
              runwayValue = runwayAmount.toStringAsFixed(2);
              isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              runwayValue = "0";
              isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = "No company data found";
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Failed to load runway data";
          isLoading = false;
        });
      }
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
              totalFundsAvailable = _isLoadingCountry
                  ? "₹$formattedFunds"
                  : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}$formattedFunds";
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
      final currentMonthBurnAmount = _calculateCurrentMonthBurn();

      if (mounted) {
        setState(() {
          monthlyBurn = currentMonthBurnAmount > 0
              ? (_isLoadingCountry
                    ? "₹${currentMonthBurnAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}"
                    : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}${currentMonthBurnAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}")
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

      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .orderBy('Date', descending: true)
          .get();

      if (mounted) {
        setState(() {
          allExpenses = expensesSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'amount': (data['Amount'] as num).toDouble(),
              'date': data['Date'],
            };
          }).toList();
        });
      }
    } catch (e) {
      log("Error fetching expenses: $e");
    }
  }

  double _calculateCurrentMonthBurn() {
    if (allExpenses.isEmpty) return 0;
    final now = DateTime.now();
    double currentMonthTotal = 0;
    for (var expense in allExpenses) {
      final expenseDate = expense['date'] as Timestamp?;
      if (expenseDate != null) {
        final dt = expenseDate.toDate();
        if (dt.month == now.month && dt.year == now.year) {
          currentMonthTotal += expense['amount'] as double;
        }
      }
    }
    return currentMonthTotal;
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
                        emptyLabel: _isLoadingCountry
                            ? "₹0"
                            : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0",
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionLabel("BURN TREND"),
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
              _buildSectionLabel("EXPENSE BREAKDOWN"),
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
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
            child: _buildDefaultAvatar(),
          ),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        // Load profile image FileId from user data
        String? profileImageFileId;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          profileImageFileId = userData['profileImageFileId'];
        }

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
              child: _buildProfileAvatar(profileImageFileId),
            ),
          ],
        );
      },
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
              _buildSectionLabel("EST. RUNWAY"),
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
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                    letterSpacing: -2,
                  ),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FIXED: FITTED BOX FOR LARGE NUMBERS
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(height: 20),
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
            // FIXED: FITTED BOX FOR LARGE NUMBERS
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value ??
                    emptyLabel ??
                    (_isLoadingCountry
                        ? "₹0"
                        : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0"),
                style: GoogleFonts.inter(
                  color: value != null ? Colors.white : Colors.white54,
                  fontSize: 24, // Slight bump in size to match aesthetics
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white54, // Changed from white38 to white54
              fontSize: 11, // Changed from 12 to 11
              fontWeight: FontWeight.bold, // Changed from w500 to bold
              letterSpacing: 1.2, // Added spacing to match section labels
            ),
          ),
        ],
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
                    // FIX 1: Ensure the Row gives bounded height to its children
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: display.map((data) {
                      final amount = (data['amount'] as num).toDouble();
                      final pct = maxAmount > 0 ? amount / maxAmount : 0.0;
                      return _buildFlatBar(
                        data['month'] as String,
                        pct,
                        amount,
                        isActive: data['isCurrentMonth'] as bool? ?? false,
                      );
                    }).toList(),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildFlatBar(
    String label,
    double pct,
    double amount, {
    bool isActive = false,
  }) {
    // FIX 2: Scale 0 to 2% (0.02) so it's not completely invisible,
    // otherwise strictly use the percentage scale for the height.
    final safePct = pct == 0.0 ? 0.02 : pct.clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            _isLoadingCountry
                ? "₹${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}"
                : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}",
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
                width: 36,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : const Color(0xFF1F1F22),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
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
                // FIXED: FITTED BOX FOR LARGE NUMBERS
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _isLoadingCountry
                          ? "₹${totalExpenses.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}"
                          : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}${totalExpenses.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [const FontFeature.tabularFigures()],
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

  Widget _buildViewAllButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MonthlyBurnScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ), // Standardized padding
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08), // White Glass effect
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Text(
              "VIEW ALL",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0, // Standardized tracking
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
