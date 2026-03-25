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

  // FIX 1: fundingHistory is now rendered (was populated but never shown).
  List<Map<String, dynamic>> fundingHistory = [];
  List<Map<String, dynamic>> allExpenses = [];
  List<Map<String, dynamic>> bankAccounts = [];
  List<Map<String, dynamic>> cashFlowBreakdown = [];

  @override
  void initState() {
    super.initState();
    // FIX 2: Load all data sequentially to avoid race condition where
    // _calculateCashFlowBreakdown() ran before allExpenses was populated.
    _loadAllData();
  }

  // FIX 2: Single async method ensures correct load order.
  Future<void> _loadAllData() async {
    await _fetchFundsData();
    await _fetchAllExpenses();
    await _fetchBankAccounts();
    _calculateCashFlowBreakdown();
    await _fetchFundingHistory();
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

        // FIX 3: Use the document's actual creation time instead of a hardcoded date.
        final createdAt = docSnapshot.get('createdAt') as Timestamp?;
        final fundingDateStr = createdAt != null
            ? _formatDate(createdAt)
            : 'Date unknown';

        setState(() {
          fundingHistory.clear();
          if (funding != null) {
            final fundingAmt = double.tryParse(funding.toString()) ?? 0;
            fundingHistory.add({
              'round': 'Initial Funding',
              'amount': fundingAmt.toInt(),
              'date': fundingDateStr,
              'status': 'completed',
            });
          }

          // If no funding data, show empty state.
        });
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

    setState(() {
      cashFlowBreakdown = categoryTotals.entries.map((entry) {
        String category = entry.key;
        if (category.isNotEmpty) {
          // FIX: Only capitalise first letter, preserve the rest.
          category = category[0].toUpperCase() + category.substring(1);
        }
        return {
          'category': category,
          'amount': -entry.value.abs().toInt(),
          'percentage': 0,
        };
      }).toList();
    });
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
      });
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

        setState(() {
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
        });
      }
    } catch (e) {
      log("Error fetching bank accounts: $e");
      setState(() => bankAccounts = []);
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
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

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
        final funding = data["Funding"] ?? data["funding"] ?? data["FUNDING"];
        final totalExpenses =
            data["totalExpenses"] ?? data["total_expenses"] ?? "0";

        if (funding != null) {
          fundingAmount = double.tryParse(funding.toString()) ?? 0;
          final totalExpensesAmount =
              double.tryParse(totalExpenses.toString()) ?? 0;
          available = fundingAmount! - totalExpensesAmount;

          setState(() {
            availableFunds = "₹ ${available!.toStringAsFixed(0)}";
            expense = "₹ ${totalExpensesAmount.toStringAsFixed(0)}";
            lastUpdated = "Today";
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = "No funding data found";
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
        errorMessage = "Failed to load funds data: $e";
        isLoading = false;
      });
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
                _buildHeader(context),
                const SizedBox(height: 32),
                _buildMainFundsCard(),
                const SizedBox(height: 32),
                // FIX 1: Now shows real funding history (Initial Funding round).
                _buildFundingHistorySection(),
                const SizedBox(height: 32),
                // Recent expenses section (the top-5 expenses list).
                _buildRecentExpensesSection(),
                const SizedBox(height: 32),
                _buildCashFlowSection(),
                const SizedBox(height: 32),
                _buildBankAccountsSection(),
                // FIX 4: Removed _buildFundingMilestones() dead stub entirely.
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
                    "Last updated: ${lastUpdated ?? '...'}",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _fetchFundsData,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
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
            Text(
              "Loading...",
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.w500,
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
                    fontSize: 48,
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
            Text(
              expense ?? "0",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w300,
                height: 1.0,
                letterSpacing: -3,
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
                  availableFunds != null
                      ? "$availableFunds (${(fundingAmount! > 0 ? (available! / fundingAmount!) * 100 : 0).toStringAsFixed(0)}% of total)"
                      : "Loading...",
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

  // FIX 1: New section that renders the actual fundingHistory list.
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
          child: fundingHistory.isEmpty
              ? Center(
                  child: Text(
                    "No funding rounds recorded",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
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
    final isActive = item['status'] == 'active';
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
              "+₹$amount",
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

  // Renamed from _buildFundingHistorySection to make its purpose clear.
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
          child: expenseTransactions.isEmpty
              ? Center(
                  child: Text(
                    "No expenses found",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
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

    if (isNegative) {
      formattedAmount = '-₹${(-amount).toString()}';
      amountColor = const Color(0xFFFF453A);
    } else {
      formattedAmount = '+₹${amount.toString()}';
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
          child: cashFlowBreakdown.isEmpty
              ? Center(
                  child: Text(
                    "No expense data yet",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
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
                          "-₹${(-totalOutflow).toStringAsFixed(0)}",
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
    final formattedAmount = isPositive
        ? "+₹${amount.toStringAsFixed(0)}"
        : "-₹${(-amount).toStringAsFixed(0)}";

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
          child: bankAccounts.isEmpty
              ? Column(
                  children: [
                    Text(
                      "No bank accounts connected",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddBankAccountScreen(),
                          ),
                        );
                        if (result == true) _fetchBankAccounts();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF30D158),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Add Bank Account",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddBankAccountScreen(),
                            ),
                          );
                          if (result == true) _fetchBankAccounts();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Text(
                          "Add Another Account",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildBankAccountItem(Map<String, dynamic> account) {
    final totalSpent = (account['totalSpent'] as num).toDouble();
    final formattedAmount = totalSpent > 0
        ? '-₹${totalSpent.toStringAsFixed(0)}'
        : '₹0';

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
