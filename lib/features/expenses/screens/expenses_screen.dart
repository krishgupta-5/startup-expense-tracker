import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// Make sure these imports match your actual file paths
import 'add_expense_screen.dart';
import 'search_expense_screen.dart';
import 'expense_details_screen.dart';
import 'scan_expense_screen.dart';
import 'report_expense_screen.dart';
import '../../../utils/data_helpers.dart';
import '../../../services/financial_calculator.dart';
import '../../../services/currency_preference_service.dart';
import '../../../services/currency_formatter.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  // State variables for metrics
  double _totalFunding = 0.0;
  double _totalExpenses = 0.0;
  double _avgDaily = 0.0;
  bool _isLoading = true;
  String _userCountryCode = '+1'; // Default to USD
  bool _isLoadingCountry = true;

  StreamSubscription? _companySubscription;
  StreamSubscription? _expensesSubscription;

  late AnimationController _shimmerController;

  // OVERRIDE wantKeepAlive to return true
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Initialize Shimmer Controller
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _shimmerController.repeat();

    // Get currency preference synchronously for instant display
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    // Listen for currency changes
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
    _loadMetricsData();
    _loadUserCountryCode();
  }

  @override
  void dispose() {
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    _companySubscription?.cancel();
    _expensesSubscription?.cancel();
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

  Future<void> _loadUserCountryCode() async {
    final currencyCode =
        await CurrencyPreferenceService.getCurrencyPreference();
    if (mounted) {
      setState(() {
        _userCountryCode = currencyCode;
        _isLoadingCountry = false;
      });
    }
  }

  Future<void> _loadMetricsData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // ✅ FIX: Get companyId from user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final companyId = userDoc.data()?['companyId'];
      if (companyId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Cancel any existing listeners
      await _companySubscription?.cancel();
      await _expensesSubscription?.cancel();

      // Listen to company document in real time
      _companySubscription = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .snapshots()
          .listen((companyDoc) {
        if (companyDoc.exists && mounted) {
          final companyData = companyDoc.data() as Map<String, dynamic>;
          setState(() {
            _totalFunding = DataHelpers.safeParseDouble(companyData['Funding']);
          });
        }
      });

      // Listen to user's expenses in real time
      _expensesSubscription = FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .snapshots()
          .listen((expensesSnapshot) {
        if (mounted) {
          double totalRealSpent = 0.0;
          // Convert expenses to format expected by FinancialCalculator
          List<Map<String, dynamic>> expenses = [];
          for (var doc in expensesSnapshot.docs) {
            final data = doc.data();
            if (data['isFunding'] != true) {
              final amt = DataHelpers.safeParseDouble(data['Amount'] ?? data['amount']);
              totalRealSpent += amt;
              expenses.add({
                'amount': amt,
                'date': data['Date'] ?? data['date'],
                'type': data['Type'] ?? data['type'] ?? 'one_time',
              });
            }
          }

          // Calculate average daily burn using rolling window (last 30 days)
          final rollingMonthlyBurn = FinancialCalculator.rollingAverageMonthlyBurn(
            expenses,
          );
          setState(() {
            _totalExpenses = totalRealSpent;
            _avgDaily = rollingMonthlyBurn / 30; // Convert to daily average
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading metrics: $e');
      if (mounted) setState(() => _isLoading = false);
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

  // --- CATEGORY ICON HELPER ---
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'marketing':
        return Icons.campaign_outlined;
      case 'infrastructure':
        return Icons.dns_outlined;
      case 'office':
        return Icons.business_outlined;
      case 'software':
        return Icons.code_outlined;
      case 'hardware':
        return Icons.computer_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'design':
        return Icons.palette_outlined;
      case 'travel':
        return Icons.flight_outlined;
      case 'meals':
        return Icons.restaurant_outlined;
      case 'contractors':
        return Icons.build_outlined;
      case 'legal':
        return Icons.gavel_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (Minimal Text Only)
              _buildMinimalHeader(),

              const SizedBox(height: 32),

              // 2. Metrics (Flat Cards)
              SizedBox(
                height: 130,
                child: _isLoading
                    ? ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        clipBehavior: Clip.none,
                        children: [
                          _buildSkeletonMetricCard(),
                          const SizedBox(width: 16),
                          _buildSkeletonMetricCard(),
                          const SizedBox(width: 16),
                          _buildSkeletonMetricCard(),
                        ],
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.none,
                        children: [
                          _buildFlatMetric(
                            "Budget Left",
                            "${_isLoadingCountry ? '₹' : CurrencyFormatter.getCurrencySymbol(_userCountryCode)}${(_totalFunding - _totalExpenses).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}",
                            "${_totalFunding > 0 ? ((_totalFunding - _totalExpenses) / _totalFunding * 100).toStringAsFixed(0) : '0'}%",
                            const Color(0xFF30D158),
                          ),
                          const SizedBox(width: 16),
                          _buildFlatMetric(
                            "Spent",
                            "${_isLoadingCountry ? '₹' : CurrencyFormatter.getCurrencySymbol(_userCountryCode)}${_totalExpenses.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}" ,
                            "${_totalFunding > 0 ? (_totalExpenses / _totalFunding * 100).toStringAsFixed(1) : '0'}% used",
                            Colors.white,
                          ),
                          const SizedBox(width: 16),
                          _buildFlatMetric(
                            "Avg. Daily",
                            "${_isLoadingCountry ? '₹' : CurrencyFormatter.getCurrencySymbol(_userCountryCode)}${_avgDaily.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}" ,
                            "30-day rolling avg",
                            Colors.white54, // Muted grey
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 40),

              // 3. Actions (Outline Style)
              _buildSectionLabel("QUICK ACTIONS"),
              const SizedBox(height: 16),
              _buildFlatActionGrid(context),

              const SizedBox(height: 40),

              // 4. Transactions (Clean List)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionLabel("TRANSACTIONS"),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchExpenseScreen(),
                        ),
                      ).then((_) => _loadMetricsData());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.05,
                        ), // Glassy white
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "VIEW ALL",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Firebase Transactions Stream
              _buildFlatTransactionList(),

              const SizedBox(height: 80), // Bottom padding for navbar
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildMinimalHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DataHelpers.formatDate(DateTime.now(), format: 'MMMM yyyy'),
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Expenses",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }

  Widget _buildFlatMetric(
    String label,
    String value,
    String badge,
    Color accent,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416), // Solid Matte Grey
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              // Tiny dot indicator
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FIXED: FITTED BOX FOR LARGE NUMBERS
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 24, // Bumped for hero impact
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlatActionGrid(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
            ).then((_) => _loadMetricsData());
          },
          child: _buildFlatActionButton("Add", Icons.add_rounded),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SearchExpenseScreen(),
              ),
            );
          },
          child: _buildFlatActionButton("Search", Icons.search_rounded),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ScanExpenseScreen(),
              ),
            ).then((_) => _loadMetricsData());
          },
          child: _buildFlatActionButton("Scan", Icons.qr_code_rounded),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReportExpenseScreen(),
              ),
            );
          },
          child: _buildFlatActionButton(
            "Report",
            Icons.insert_chart_outlined_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildFlatActionButton(String label, IconData icon) {
    return Column(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05), // Premium Glassy style
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- FIREBASE TOP 5 EXPENSES STREAM ---
  Widget _buildFlatTransactionList() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          "User not logged in.",
          style: GoogleFonts.inter(color: Colors.white54),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .orderBy('Date', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: [
              _buildSkeletonTransaction(),
              _buildSkeletonTransaction(),
              _buildSkeletonTransaction(),
              _buildSkeletonTransaction(),
            ],
          );
        }

        if (snapshot.hasError) {
          debugPrint("🚨 FIRESTORE ERROR: ${snapshot.error}");
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "Error loading transactions. Check console for Index Link.",
              style: GoogleFonts.inter(color: Colors.redAccent),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                "No recent transactions found.",
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final expenseId = doc.id; // Get the unique document ID
            return _buildTransactionItem(data, expenseId, context);
          }).toList(),
        );
      },
    );
  }

  Widget _buildTransactionItem(
    Map<String, dynamic> tx,
    String expenseId,
    BuildContext context,
  ) {
    final title = DataHelpers.safeParseString(tx['Title']);
    final amount = DataHelpers.safeParseDouble(tx['Amount']);
    final formattedAmount = _isLoadingCountry
        ? DataHelpers.formatCurrency(amount)
        : CurrencyFormatter.formatByCountry(amount, _userCountryCode);
    // Format category to capitalize first letter or match your style
    final String rawCategory = DataHelpers.safeParseString(tx['Category']);
    final category = rawCategory.isNotEmpty
        ? '${rawCategory[0].toUpperCase()}${rawCategory.substring(1)}'
        : 'General';

    // Parse date for display in the row
    String dateStr = '';
    if (tx['Date'] is Timestamp) {
      final d = (tx['Date'] as Timestamp).toDate();
      dateStr = '${d.day}/${d.month}/${d.year}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ExpenseDetailsScreen(expenseId: expenseId, expenseData: tx),
            ),
          ).then((_) => _loadMetricsData());
        },
        child: Material(
          color: Colors.transparent,
          child: Row(
            children: [
              // Premium Icon Container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  _getCategoryIcon(rawCategory),
                  color: Colors.white54,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),

              // Info - Make entire row clickable
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          category,
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (dateStr.isNotEmpty) ...[  
                          Text(
                            ' · $dateStr',
                            style: GoogleFonts.inter(
                              color: Colors.white24,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Amount
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formattedAmount,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [
                      const FontFeature.tabularFigures(),
                    ], // Aligns numbers
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SHIMMER LOADING WIDGETS ---

  Widget _buildShimmerEffect(
    double width,
    double height, {
    double borderRadius = 8,
  }) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final value = _shimmerController.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
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

  Widget _buildSkeletonMetricCard() {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildShimmerEffect(70, 12, borderRadius: 4),
              _buildShimmerEffect(8, 8, borderRadius: 4),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShimmerEffect(90, 24, borderRadius: 6),
              const SizedBox(height: 8),
              _buildShimmerEffect(40, 12, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonTransaction() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          _buildShimmerEffect(44, 44, borderRadius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerEffect(140, 16, borderRadius: 4),
                const SizedBox(height: 8),
                _buildShimmerEffect(80, 12, borderRadius: 4),
              ],
            ),
          ),
          _buildShimmerEffect(60, 16, borderRadius: 4),
        ],
      ),
    );
  }
}
