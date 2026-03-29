import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';
import 'add_bank_account_screen.dart';
import '../../expenses/screens/expense_details_screen.dart';
import '../../../services/financial_calculator.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/currency_preference_service.dart';
import '../../../services/bank_account_service.dart';

class FundsOverviewScreen extends StatefulWidget {
  const FundsOverviewScreen({super.key});

  @override
  State<FundsOverviewScreen> createState() => _FundsOverviewScreenState();
}

class _FundsOverviewScreenState extends State<FundsOverviewScreen> {
  String? expense;
  String? availableFunds;
  String? lastUpdated;
  bool isLoading = true;
  String? errorMessage;
  double? fundingAmount;
  double? available;

  List<Map<String, dynamic>> fundingHistory = [];
  List<Map<String, dynamic>> allExpenses = [];
  List<Map<String, dynamic>> bankAccounts = [];
  List<Map<String, dynamic>> cashFlowBreakdown = [];

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
      // Reload data to refresh currency formatting
      _loadAllData();
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
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Fetch all data sequentially without triggering false loading states
      await _fetchFundsData();
      await _fetchAllExpenses();
      await _fetchBankAccounts();
      _calculateCashFlowBreakdown();
      await _fetchFundingHistory();
    } catch (e) {
      log("Error loading all data: $e");
      if (mounted) {
        setState(() {
          errorMessage = "Failed to load some data. Pull down to refresh.";
        });
      }
    } finally {
      // ONLY set isLoading to false when EVERYTHING is done
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _fetchFundingHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docSnapshot = await FirebaseFirestore.instance
          .collection("companies")
          .doc(user.uid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final funding = data["Funding"] ?? data["funding"] ?? data["FUNDING"];

        final createdAt = docSnapshot.get('createdAt') as Timestamp?;
        final fundingDateStr = createdAt != null
            ? _formatDate(createdAt)
            : 'Date unknown';

        fundingHistory.clear();
        if (funding != null) {
          final fundingAmt = double.tryParse(funding.toString()) ?? 0;
          if (fundingAmt > 0) {
            fundingHistory.add({
              'round': 'Initial Funding',
              'amount': fundingAmt.toInt(),
              'date': fundingDateStr,
              'status': 'completed',
            });
          }
        }
      }
    } catch (e) {
      log("Error fetching funding history: $e");
    }
  }

  void _calculateCashFlowBreakdown() {
    final Map<String, double> categoryTotals = {};
    for (var expense in allExpenses) {
      final category = expense['category'] as String? ?? 'Other';
      final amount = (expense['amount'] as num).toDouble();
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }

    cashFlowBreakdown = categoryTotals.entries.map((entry) {
      String category = entry.key;
      if (category.isNotEmpty) {
        category = category[0].toUpperCase() + category.substring(1);
      }
      return {
        'category': category,
        'amount': -entry.value.abs().toInt(),
        'percentage': 0,
      };
    }).toList();
  }

  String _getHealthStatus() {
    if (isLoading || available == null || fundingAmount == null) {
      return "NO DATA";
    }

    final runwayMonths = FinancialCalculator.runwayMonths(
      availableFunds: available!,
      monthlyBurn: _calculateCurrentMonthBurn(),
    );

    return FinancialCalculator.runwayHealthStatus(runwayMonths);
  }

  Color _getHealthStatusColor() {
    final status = _getHealthStatus();
    switch (status) {
      case "SAFE":
        return const Color(0xFF30D158);
      case "WARNING":
        return const Color(0xFFFF9F0A);
      case "CRITICAL":
        return const Color(0xFFFF453A);
      default:
        return Colors.white54;
    }
  }

  double _calculateCurrentMonthBurn() {
    if (allExpenses.isEmpty) return 0;
    final now = DateTime.now();
    double currentMonthTotal = 0;
    for (var expense in allExpenses) {
      final expenseDate = expense['date'] as String?;
      if (expenseDate != null) {
        // Parse date string and check if it's current month
        final parts = expenseDate.split('/');
        if (parts.length >= 2) {
          final month = int.tryParse(parts[0]);
          final year = int.tryParse(parts[1]);
          if (month != null &&
              year != null &&
              month == now.month &&
              year == now.year) {
            currentMonthTotal += (expense['amount'] as num).toDouble();
          }
        }
      }
    }
    return currentMonthTotal;
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

      allExpenses = expensesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['Title'] ?? 'Unnamed Expense',
          'amount': (data['Amount'] as num).toInt(),
          'category': data['Category'] ?? 'General',
          'date': data['Date'] != null
              ? _formatDate(data['Date'])
              : 'Unknown Date',
          'description': data['Description'] ?? '',
          'type': data['Type'] ?? 'one_time',
          'bankAccount':
              data['BankAccount'] ??
              data['Bank Account'] ??
              data['bankAccount'] ??
              'N/A',
        };
      }).toList();
    } catch (e) {
      log("Error fetching expenses: $e");
    }
  }

  Future<void> _fetchBankAccounts() async {
    try {
      debugPrint('🔍 DEBUG Funds Overview: Starting _fetchBankAccounts()');
      // Use BankAccountService for consistent bank account processing
      final accountsWithSpending =
          await BankAccountService.getBankAccountsWithSpending(allExpenses);

      debugPrint(
        '🔍 DEBUG Funds Overview: BankAccountService returned ${accountsWithSpending.length} accounts',
      );
      for (var account in accountsWithSpending) {
        debugPrint('🔍 DEBUG Funds Overview: Account - $account');
      }

      if (mounted) {
        setState(() {
          bankAccounts = accountsWithSpending;
        });
      }
    } catch (e, stackTrace) {
      debugPrint(
        '🔍 DEBUG Funds Overview: Exception in _fetchBankAccounts(): $e',
      );
      debugPrint('🔍 DEBUG Funds Overview: Stack trace: $stackTrace');
      log("Error fetching bank accounts: $e");
      if (mounted) {
        setState(() {
          bankAccounts = [];
        });
      }
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _fetchFundsData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        errorMessage = "User not authenticated";
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
          fundingAmount = double.tryParse(funding.toString()) ?? 0;
          final totalExpensesAmount =
              double.tryParse(totalExpenses.toString()) ?? 0;
          available = fundingAmount! - totalExpensesAmount;

          // Add Indian comma formatting to large numbers
          String formattedAvailable = available!
              .toStringAsFixed(0)
              .replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (match) => '${match[1]},',
              );
          String formattedExpense = totalExpensesAmount
              .toStringAsFixed(0)
              .replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (match) => '${match[1]},',
              );

          availableFunds = _isLoadingCountry
              ? "₹ $formattedAvailable"
              : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)} $formattedAvailable";
          expense = _isLoadingCountry
              ? "₹ $formattedExpense"
              : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)} $formattedExpense";
          lastUpdated = "Today";
        } else {
          errorMessage = "No funding data found";
        }
      } else {
        errorMessage = "No company data found";
      }
    } catch (e) {
      errorMessage = "Failed to load funds data";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadAllData,
            color: Colors.black,
            backgroundColor: Colors.white,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 32),

                  // Total Expenses Display
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isLoading
                          ? "--"
                          : (expense ??
                                (_isLoadingCountry
                                    ? "₹0"
                                    : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0")),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 48, // Bumped size for hero impact
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Total Outflow",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 32),
                  _buildMainFundsCard(),
                  const SizedBox(height: 32),
                  _buildFundingHistorySection(),
                  const SizedBox(height: 32),
                  _buildRecentExpensesSection(),
                  const SizedBox(height: 32),
                  _buildCashFlowSection(),
                  const SizedBox(height: 32),
                  _buildBankAccountsSection(),
                  const SizedBox(height: 40),
                ],
              ),
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
              color: Colors.white.withValues(
                alpha: 0.05,
              ), // White Glass matched
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
              "Funds Overview",
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Capital Analysis",
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

  Widget _buildMainFundsCard() {
    return Container(
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
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    "Updated: ${lastUpdated ?? '--'}",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _loadAllData,
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
          const SizedBox(height: 24),
          Text(
            "AVAILABLE FOR OPERATIONS",
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isLoading
                  ? "--"
                  : (availableFunds != null
                        ? "$availableFunds"
                        : (_isLoadingCountry
                              ? "₹0"
                              : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0")),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32, // Large enough, but fitted
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
            ),
          ),
          if (!isLoading &&
              availableFunds != null &&
              fundingAmount != null &&
              fundingAmount! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "${((available! / fundingAmount!) * 100).toStringAsFixed(1)}% of total capital remaining",
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFundingHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("FUNDING HISTORY"),
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
              ? _buildEmptyState("Loading history...")
              : fundingHistory.isEmpty
              ? _buildEmptyState("No funding rounds recorded")
              : Column(
                  children: fundingHistory.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isLast = index == fundingHistory.length - 1;
                    return Column(
                      children: [
                        _buildFundingItem(item),
                        if (!isLast) ...[
                          const SizedBox(height: 16),
                          Divider(
                            color: Colors.white.withValues(alpha: 0.04),
                            height: 1,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildFundingItem(Map<String, dynamic> item) {
    final amount = (item['amount'] as num).toInt();
    final isActive =
        item['status'] == 'active' || item['status'] == 'completed';

    String formattedAmount = _isLoadingCountry
        ? "+₹${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}"
        : "+${CurrencyFormatter.formatByCountry(amount.toDouble(), _userCountryCode)}";

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF30D158).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF30D158).withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.account_balance,
            color: Color(0xFF30D158),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['round'] as String,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item['date'] as String,
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formattedAmount,
                style: GoogleFonts.inter(
                  color: const Color(0xFF30D158),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "COMPLETED",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF30D158),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentExpensesSection() {
    final List<Map<String, dynamic>> expenseTransactions = allExpenses
        .take(5)
        .map(
          (expense) => {
            'id': expense['id'],
            'round': expense['title'],
            'amount': -(expense['amount'] as int),
            'date': expense['date'],
            'status': 'completed',
            'type': 'expense',
            'category': expense['category'],
            'description': expense['description'],
          },
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("RECENT EXPENSES"),
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
              ? _buildEmptyState("Loading expenses...")
              : expenseTransactions.isEmpty
              ? _buildEmptyState("No recent expenses")
              : Column(
                  children: expenseTransactions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final transaction = entry.value;
                    final isLast = index == expenseTransactions.length - 1;
                    return GestureDetector(
                      onTap: () => _navigateToExpenseDetails(transaction),
                      child: Column(
                        children: [
                          _buildTransactionItem(transaction),
                          if (!isLast) ...[
                            const SizedBox(height: 16),
                            Divider(
                              color: Colors.white.withValues(alpha: 0.04),
                              height: 1,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isExpense = transaction['type'] == 'expense';
    final isActive = transaction['status'] == 'active';
    final amount = (transaction['amount'] as num).toInt();
    final isNegative = amount < 0;

    String formattedAmount;
    Color amountColor;

    String cleanAmount = amount.abs().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

    if (isNegative) {
      formattedAmount = _isLoadingCountry
          ? '-₹$cleanAmount'
          : '-${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}$cleanAmount';
      amountColor = const Color(0xFFFF453A);
    } else {
      formattedAmount = _isLoadingCountry
          ? '+₹$cleanAmount'
          : '+${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}$cleanAmount';
      amountColor = isActive ? const Color(0xFF30D158) : Colors.white;
    }

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isExpense
                ? const Color(0xFFFF453A).withValues(alpha: 0.1)
                : isActive
                ? const Color(0xFF30D158).withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExpense
                  ? const Color(0xFFFF453A).withValues(alpha: 0.3)
                  : isActive
                  ? const Color(0xFF30D158).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            isExpense
                ? Icons.receipt
                : (isActive ? Icons.trending_up : Icons.account_balance),
            color: isExpense
                ? const Color(0xFFFF453A)
                : (isActive ? const Color(0xFF30D158) : Colors.white38),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction['round'],
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                isExpense
                    ? '${transaction['category']} • ${transaction['date']}'
                    : transaction['date'],
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              formattedAmount,
              style: GoogleFonts.inter(
                color: amountColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCashFlowSection() {
    final totalOutflow = cashFlowBreakdown
        .where((item) => item['amount'] < 0)
        .fold<int>(0, (total, item) => total + (item['amount'] as int));

    final formattedOutflow = totalOutflow.abs().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("CASH FLOW BREAKDOWN"),
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
              ? _buildEmptyState("Loading cash flow...")
              : cashFlowBreakdown.isEmpty
              ? _buildEmptyState("No cash flow data")
              : Column(
                  children: [
                    ...cashFlowBreakdown.map(
                      (item) => _buildCashFlowItem(item),
                    ),
                    const SizedBox(height: 8),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.04),
                      height: 1,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Outflow",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _isLoadingCountry
                                  ? "-₹$formattedOutflow"
                                  : "-${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}$formattedOutflow",
                              style: GoogleFonts.inter(
                                color: const Color(0xFFFF453A),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCashFlowItem(Map<String, dynamic> item) {
    final amount = item['amount'] as int;
    final isPositive = amount >= 0;

    final cleanAmount = amount.abs().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    final formattedAmount = _isLoadingCountry
        ? (isPositive ? "+₹$cleanAmount" : "-₹$cleanAmount")
        : (isPositive
              ? "+${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}$cleanAmount"
              : "-${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}$cleanAmount");

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFF30D158)
                  : const Color(0xFFFF453A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item['category'],
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formattedAmount,
                style: GoogleFonts.inter(
                  color: isPositive
                      ? const Color(0xFF30D158)
                      : const Color(0xFFFF453A),
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

  void _navigateToExpenseDetails(Map<String, dynamic> transaction) {
    if (transaction['id'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExpenseDetailsScreen(
            expenseId: transaction['id'],
            expenseData: transaction,
          ),
        ),
      );
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF30D158),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
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
        duration: const Duration(seconds: 3),
        elevation: 0,
      ),
    );
  }

  void _showDeleteAccountDialog(Map<String, dynamic> account) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141416),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            'Delete Bank Account',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${account['name']}"? This action cannot be undone.',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteBankAccount(account);
              },
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF453A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBankAccount(Map<String, dynamic> account) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final accountId = account['id'] as String?;
      if (accountId == null) {
        _showErrorMessage('Cannot delete account: Missing account ID');
        return;
      }

      debugPrint(
        '🔍 DEBUG: Attempting to delete bank account with ID: $accountId',
      );

      // Try to delete from subcollection first (new model)
      try {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(user.uid)
            .collection('bankAccounts')
            .doc(accountId)
            .delete();

        debugPrint('🔍 DEBUG: Successfully deleted from subcollection');
        _showSuccessMessage('Bank account deleted successfully');
        await _loadAllData();
        return;
      } catch (e) {
        debugPrint('🔍 DEBUG: Failed to delete from subcollection: $e');

        // Fallback: try to remove from company array (old model)
        try {
          final companyDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(user.uid)
              .get();

          if (companyDoc.exists && companyDoc.data() != null) {
            final data = companyDoc.data()!;
            final bankAccounts = data["Bank Accounts"] as List<dynamic>? ?? [];

            // Find and remove the account by matching name and last4
            final updatedAccounts = bankAccounts.where((accountData) {
              if (accountData is Map<String, dynamic>) {
                final bankName =
                    accountData['name']?.toString() ??
                    accountData['bankName']?.toString() ??
                    '';
                final last4 =
                    accountData['last4']?.toString() ??
                    accountData['number']?.toString() ??
                    '';

                return !((bankName == account['name']?.toString()) &&
                    (last4 == account['last4']?.toString()));
              }
              return true;
            }).toList();

            await FirebaseFirestore.instance
                .collection('companies')
                .doc(user.uid)
                .update({'Bank Accounts': updatedAccounts});

            debugPrint('🔍 DEBUG: Successfully deleted from company array');
            _showSuccessMessage('Bank account deleted successfully');
            await _loadAllData();
          }
        } catch (fallbackError) {
          debugPrint(
            '❌ DEBUG: Failed to delete from company array: $fallbackError',
          );
          _showErrorMessage('Failed to delete bank account');
        }
      }
    } catch (e) {
      debugPrint('❌ DEBUG: Error deleting bank account: $e');
      _showErrorMessage('Failed to delete bank account');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF453A), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
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
        duration: const Duration(seconds: 3),
        elevation: 0,
      ),
    );
  }

  Widget _buildBankAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("BANK ACCOUNTS"),
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
              ? _buildEmptyState("Loading accounts...")
              : bankAccounts.isEmpty
              ? Column(
                  children: [
                    _buildEmptyState("No bank accounts connected"),
                    const SizedBox(height: 16),
                    _buildAddAccountButton(),
                  ],
                )
              : Column(
                  children: [
                    ...bankAccounts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final account = entry.value;
                      final isLast = index == bankAccounts.length - 1;
                      return Column(
                        children: [
                          _buildBankAccountItem(account),
                          if (!isLast) ...[
                            const SizedBox(height: 16),
                            Divider(
                              color: Colors.white.withValues(alpha: 0.04),
                              height: 1,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      );
                    }),
                    const SizedBox(height: 24),
                    _buildAddAccountButton(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAddAccountButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddBankAccountScreen()),
        );
        if (result == true) {
          _loadAllData(); // Reload everything to ensure sync
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05), // White glass style
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              "Add Bank Account",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankAccountItem(Map<String, dynamic> account) {
    final totalSpent = (account['totalSpent'] as num).toDouble();

    // Handle multiple possible field names for bank name
    final bankName =
        account['name']?.toString() ??
        account['bankName']?.toString() ??
        account['bank_name']?.toString() ??
        'Unknown Bank';

    final cleanSpent = totalSpent
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
    final formattedAmount = totalSpent > 0
        ? (_isLoadingCountry
              ? '-₹$cleanSpent'
              : '-${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}$cleanSpent')
        : (_isLoadingCountry
              ? '₹0'
              : '${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0');

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF30D158).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF30D158).withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.account_balance,
            color: Color(0xFF30D158),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bankName,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                account['maskedNumber']?.toString() ?? '****',
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formattedAmount,
                style: GoogleFonts.inter(
                  color: totalSpent > 0
                      ? const Color(0xFFFF453A)
                      : Colors.white38,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "total transactions",
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
