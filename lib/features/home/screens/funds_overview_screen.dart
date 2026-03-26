import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';
import 'add_bank_account_screen.dart';
import '../../expenses/screens/expense_details_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAllData();
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docSnapshot = await FirebaseFirestore.instance
          .collection("companies")
          .doc(user.uid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final bankAccountsData = data["Bank Accounts"] as List<dynamic>? ?? [];

        final Map<String, double> bankSpending = {};
        for (var account in bankAccountsData) {
          final bankName = account["name"] ?? 'Unknown Bank';
          final accountNumber = account["number"] ?? '';
          bankSpending["$bankName-$accountNumber"] = 0.0;
        }

        for (var expense in allExpenses) {
          final amount = (expense['amount'] as num).toDouble();
          final expenseBankAccount = expense['bankAccount'] as String?;
          if (expenseBankAccount != null &&
              bankSpending.containsKey(expenseBankAccount)) {
            bankSpending[expenseBankAccount] =
                bankSpending[expenseBankAccount]! + amount;
          }
        }

        bankAccounts = bankAccountsData.asMap().entries.map((entry) {
          final account = entry.value;
          final bankName = account["name"] ?? 'Unknown Bank';
          final accountNumber = account["number"] ?? '';
          final totalSpent = bankSpending["$bankName-$accountNumber"] ?? 0.0;
          return {
            'name': bankName,
            'number': accountNumber,
            'maskedNumber': _maskAccountNumber(accountNumber),
            'totalSpent': totalSpent,
          };
        }).toList();
      }
    } catch (e) {
      log("Error fetching bank accounts: $e");
      bankAccounts = [];
    }
  }

  String _maskAccountNumber(String accountNumber) {
    if (accountNumber.length <= 4) return accountNumber;
    return accountNumber.substring(0, 2) +
        '*' * (accountNumber.length - 4) +
        accountNumber.substring(accountNumber.length - 2);
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

          availableFunds = "₹ $formattedAvailable";
          expense = "₹ $formattedExpense";
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
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ), // Matched Alpha
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
                  color: const Color(0xFF30D158).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFF30D158).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  "HEALTHY",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF30D158),
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
                    "Last updated: ${lastUpdated ?? '--'}",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
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
          const SizedBox(height: 32),

          Text(
            isLoading ? "--" : (expense ?? "₹0"),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w300,
              height: 1.0,
              letterSpacing: -2,
            ),
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
                  "Available for Operations",
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLoading
                      ? "--"
                      : (availableFunds != null
                            ? "$availableFunds (${(fundingAmount! > 0 ? (available! / fundingAmount!) * 100 : 0).toStringAsFixed(0)}% of total)"
                            : "₹0"),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
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

  Widget _buildFundingHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Funding History",
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
                          const SizedBox(height: 20),
                          Divider(
                            color: Colors.white.withValues(alpha: 0.06),
                            height: 1,
                          ),
                          const SizedBox(height: 20),
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
    // Format large numbers
    String formattedAmount =
        "+₹${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}";

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
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formattedAmount,
              style: GoogleFonts.inter(
                color: const Color(0xFF30D158),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  "ACTIVE",
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
        Text(
          "Recent Expenses",
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
                            const SizedBox(height: 20),
                            Divider(
                              color: Colors.white.withValues(alpha: 0.06),
                              height: 1,
                            ),
                            const SizedBox(height: 20),
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
      formattedAmount = '-₹$cleanAmount';
      amountColor = const Color(0xFFFF453A);
    } else {
      formattedAmount = '+₹$cleanAmount';
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
              ),
            ],
          ),
        ),
        Text(
          formattedAmount,
          style: GoogleFonts.inter(
            color: amountColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
        Text(
          "Cash Flow Breakdown",
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
                    const SizedBox(height: 16),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.1),
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
                        Text(
                          "-₹$formattedOutflow",
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF453A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
    final formattedAmount = isPositive ? "+₹$cleanAmount" : "-₹$cleanAmount";

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
            ),
          ),
          Text(
            formattedAmount,
            style: GoogleFonts.inter(
              color: isPositive
                  ? const Color(0xFF30D158)
                  : const Color(0xFFFF453A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
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

  Widget _buildBankAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Bank Accounts",
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
                              color: Colors.white.withValues(alpha: 0.06),
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

  // Standardized minimal button for adding accounts
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(16),
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

    final cleanSpent = totalSpent
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
    final formattedAmount = totalSpent > 0 ? '-₹$cleanSpent' : '₹0';

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
                account['name'],
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                account['maskedNumber'],
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formattedAmount,
              style: GoogleFonts.inter(
                color: totalSpent > 0
                    ? const Color(0xFFFF453A)
                    : Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "total spent",
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
