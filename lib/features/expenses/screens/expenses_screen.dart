// Required for FontFeature
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

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

// 1. ADD AutomaticKeepAliveClientMixin
class _ExpensesScreenState extends State<ExpensesScreen>
    with AutomaticKeepAliveClientMixin {
  // State variables for metrics
  double _totalFunding = 0.0;
  double _totalExpenses = 0.0;
  double _avgDaily = 0.0;
  int _daysFromStart = 1;
  bool _isLoading = true;

  // 2. OVERRIDE wantKeepAlive to return true
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMetricsData();
  }

  Future<void> _loadMetricsData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Load company funding data
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(user.uid)
          .get();

      if (companyDoc.exists) {
        final companyData = companyDoc.data() as Map<String, dynamic>;
        final fundingStr = companyData['Funding']?.toString() ?? '0';
        _totalFunding =
            double.tryParse(fundingStr.replaceAll(RegExp(r'[^\d.]'), '')) ??
            0.0;
      }

      // Load all expenses to calculate totals
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .get();

      double totalSpent = 0.0;
      DateTime? earliestDate;

      for (var doc in expensesSnapshot.docs) {
        final data = doc.data();
        final amountStr = data['Amount']?.toString() ?? '0';
        final amount =
            double.tryParse(amountStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        totalSpent += amount;

        // Track earliest date for days calculation
        if (data['Date'] != null) {
          final date = data['Date'].toDate();
          if (earliestDate == null || date.isBefore(earliestDate)) {
            earliestDate = date;
          }
        }
      }

      _totalExpenses = totalSpent;

      // Calculate days from start date
      if (earliestDate != null) {
        _daysFromStart = DateTime.now().difference(earliestDate).inDays;
        if (_daysFromStart < 1) _daysFromStart = 1; // Avoid division by zero
      }

      // Calculate average daily spending
      _avgDaily = _totalExpenses / _daysFromStart;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading metrics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 3. CALL super.build(context)
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
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white38,
                        ),
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.none,
                        children: [
                          _buildFlatMetric(
                            "Budget Left",
                            "₹${(_totalFunding - _totalExpenses).toStringAsFixed(0)}",
                            "${_totalFunding > 0 ? ((_totalFunding - _totalExpenses) / _totalFunding * 100).toStringAsFixed(0) : '0'}%",
                            const Color(0xFF30D158),
                          ),
                          const SizedBox(width: 16),
                          _buildFlatMetric(
                            "Spent",
                            "₹${_totalExpenses.toStringAsFixed(0)}",
                            "+${(_totalExpenses > 0 ? '0' : '0')}%", // Placeholder logic
                            Colors.white,
                          ),
                          const SizedBox(width: 16),
                          _buildFlatMetric(
                            "Avg. Daily",
                            "₹${_avgDaily.toStringAsFixed(0)}",
                            "-${(_avgDaily > 0 ? '0' : '0')}%", // Placeholder logic
                            Colors.grey,
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 40),

              // 3. Actions (Outline Style)
              Text(
                "QUICK ACTIONS",
                style: GoogleFonts.inter(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildFlatActionGrid(context),

              const SizedBox(height: 40),

              // 5. Transactions (Clean List)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "TRANSACTIONS",
                    style: GoogleFonts.inter(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
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
                    child: Text(
                      "VIEW ALL",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
          "November", // You might want to make this dynamic later!
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416), // Solid Matte Grey
        borderRadius: BorderRadius.circular(16),
        // No Shadow, just a barely visible border for definition
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                badge,
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
            // 4. Update data silently when returning from Add
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
            // Update data silently when returning from Scan too
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
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 11,
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white38,
              ),
            ),
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
                style: GoogleFonts.inter(color: Colors.white54),
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
    final title = tx['Title'] ?? 'Unnamed Expense';
    final amount = tx['Amount']?.toString() ?? '0.00';
    // Format category to capitalize first letter or match your style
    final String rawCategory = tx['Category'] ?? 'General';
    final category = rawCategory.isNotEmpty
        ? '${rawCategory[0].toUpperCase()}${rawCategory.substring(1)}'
        : 'General';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () {
          // Listen for returns here as well if you can edit/delete expenses
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
              // Minimal Icon Placeholder (No container)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt,
                  color: Colors.white38,
                  size: 18,
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
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category,
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount - Not clickable
              Text(
                "₹$amount",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [
                    const FontFeature.tabularFigures(),
                  ], // Aligns numbers
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
