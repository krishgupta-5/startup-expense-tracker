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
import '../../../utils/expense_expansion_helper.dart';
import '../../../theme/app_theme.dart';

class FundsOverviewScreen extends StatefulWidget {
  const FundsOverviewScreen({super.key});

  @override
  State<FundsOverviewScreen> createState() => _FundsOverviewScreenState();
}

class _FundsOverviewScreenState extends State<FundsOverviewScreen> {
  // Raw financial data — always kept in sync via setState
  double _totalExpensesAmount = 0.0;
  double _availableAmount = 0.0;
  bool _dataLoaded = false;

  String? lastUpdated;
  bool isLoading = true;
  String? errorMessage;
  double? fundingAmount;

  List<Map<String, dynamic>> fundingHistory = [];
  List<Map<String, dynamic>> allExpenses = [];
  List<Map<String, dynamic>> bankAccounts = [];
  List<Map<String, dynamic>> cashFlowBreakdown = [];
  double _totalSalaries = 0.0;

  String _userCountryCode = '+1'; // Default to USD

  @override
  void initState() {
    super.initState();
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
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
      await Future.wait([
        _fetchFundsData(),
        _fetchAllExpenses(),
        _fetchSalaries(),
      ]);

      if (fundingAmount != null) {
        final now = DateTime.now();
        final totalReal = allExpenses.fold<double>(0.0, (t, e) {
          final ts = e['timestamp'] as Timestamp?;
          if (ts != null && ts.toDate().isAfter(now)) {
            return t;
          }
          return t + (e['rawAmount'] as double? ?? 0.0);
        });
        setState(() {
          _totalExpensesAmount = totalReal;
          _availableAmount = fundingAmount! - totalReal;
          lastUpdated = 'Today';
          _dataLoaded = true;
        });
      }

      _calculateCashFlowBreakdown();

      await Future.wait([_fetchBankAccounts(), _fetchFundingHistory()]);
    } catch (e) {
      log('Error loading all data: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load some data. Pull down to refresh.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _fetchFundsData() async {
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
        if (mounted) {
          setState(() {
            if (funding != null) {
              if (funding is num) {
                fundingAmount = funding.toDouble();
              } else if (funding is String) {
                fundingAmount = double.tryParse(
                  funding.replaceAll(RegExp(r'[^\d.-]'), ''),
                );
              }
            }
          });
        }
      }
    } catch (e) {
      log("Error fetching funds data: $e");
    }
  }

  Future<void> _fetchSalaries() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('uid', isEqualTo: user.uid)
          .get();

      double salariesTotal = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final salaryVal = data['salary'] ?? data['Salary'];
        if (salaryVal is num) {
          salariesTotal += salaryVal.toDouble();
        } else if (salaryVal is String) {
          salariesTotal +=
              double.tryParse(salaryVal.replaceAll(RegExp(r'[^\d.-]'), '')) ??
              0.0;
        }
      }

      if (mounted) {
        setState(() {
          _totalSalaries = salariesTotal;
        });
      }
    } catch (e) {
      log("Error fetching salaries: $e");
    }
  }

  Future<void> _fetchBankAccounts() async {
    try {
      final accounts = await BankAccountService.getBankAccounts();
      if (mounted) {
        setState(() {
          bankAccounts = accounts;
        });
      }
    } catch (e) {
      log("Error fetching bank accounts: $e");
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

      fundingHistory.clear();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final totalFunding = double.tryParse(
              (data["Funding"] ?? data["funding"] ?? data["FUNDING"] ?? 0)
                  .toString(),
            ) ??
            0;

        final createdAt = data['createdAt'] as Timestamp?;
        final companyDateStr =
            createdAt != null ? _formatDate(createdAt) : 'Date unknown';

        double additionalFundingTotal = 0;
        final List<Map<String, dynamic>> txnEntries = [];

        try {
          final txnSnapshot = await FirebaseFirestore.instance
              .collection('funding_transactions')
              .where('uid', isEqualTo: user.uid)
              .get();

          final sortedDocs = txnSnapshot.docs.toList()
            ..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return aTime.compareTo(bTime);
            });

          int roundNumber = 2;
          for (var doc in sortedDocs) {
            final txnData = doc.data();
            final amt = (txnData['amount'] as num?)?.toDouble() ?? 0;
            final source = txnData['source'] ?? 'Funding';
            final txnCreatedAt = txnData['createdAt'] as Timestamp?;
            final txnDateStr =
                txnCreatedAt != null ? _formatDate(txnCreatedAt) : 'Recent';

            additionalFundingTotal += amt;
            txnEntries.add({
              'round': 'Round $roundNumber · $source',
              'amount': amt.toInt(),
              'date': txnDateStr,
              'status': 'completed',
            });
            roundNumber++;
          }
        } catch (e) {
          log("Error fetching funding transactions: $e");
        }

        final initialFunding = totalFunding - additionalFundingTotal;

        if (initialFunding > 0) {
          fundingHistory.add({
            'round': 'Initial Funding',
            'amount': initialFunding.toInt(),
            'date': companyDateStr,
            'status': 'completed',
          });
        }

        fundingHistory.addAll(txnEntries);
      }
    } catch (e) {
      log("Error fetching funding history: $e");
    }
  }

  String _formatDate(Timestamp timestamp) {
    final dt = timestamp.toDate();
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
    return "${months[dt.month - 1]} ${dt.year}";
  }

  void _calculateCashFlowBreakdown() {
    final Map<String, double> categoryTotals = {};
    final now = DateTime.now();
    for (var expense in allExpenses) {
      final ts = expense['timestamp'] as Timestamp?;
      if (ts != null && ts.toDate().isAfter(now)) {
        continue;
      }
      final category = expense['category'] as String? ?? 'Other';
      final amount =
          (expense['rawAmount'] as num?)?.toDouble() ??
          (expense['amount'] as num?)?.toDouble() ??
          (expense['Amount'] as num?)?.toDouble() ??
          0.0;
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
    if (isLoading || !_dataLoaded || fundingAmount == null) {
      return 'NO DATA';
    }

    final runwayMonths = FinancialCalculator.runwayMonths(
      availableFunds: _availableAmount,
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
        return context.textSecondary;
    }
  }

  double _calculateCurrentMonthBurn() {
    if (allExpenses.isEmpty) return 0.0;
    final now = DateTime.now();
    double currentMonthTotal = 0;
    for (var expense in allExpenses) {
      final ts = expense['timestamp'] as Timestamp?;
      if (ts != null) {
        final dt = ts.toDate();
        if (dt.month == now.month && dt.year == now.year) {
          currentMonthTotal += expense['rawAmount'] as double? ?? 0.0;
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
          .get();

      final rawExpenses = expensesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {...data, 'id': doc.id};
      }).toList();

      final now = DateTime.now();
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final expandedList = ExpenseExpansionHelper.expandExpenses(
        rawExpenses,
        maxDate: endOfMonth,
        allowFuture: true,
      );

      final List<Map<String, dynamic>> loadedExpenses = [];
      for (final data in expandedList) {
        if (data['isFunding'] == true) continue;

        final amountVal = data['Amount'] ?? data['amount'];
        double amt = 0.0;
        if (amountVal is num) {
          amt = amountVal.toDouble();
        } else if (amountVal is String) {
          amt = double.tryParse(amountVal.replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0.0;
        }

        final title = data['Title'] ?? data['title'] ?? 'Expense';
        final category = data['Category'] ?? data['category'] ?? 'Other';
        final description = data['Description'] ?? data['description'] ?? '';
        final dateVal = data['Date'] ?? data['date'];

        Timestamp? ts;
        if (dateVal is Timestamp) {
          ts = dateVal;
        } else if (dateVal is DateTime) {
          ts = Timestamp.fromDate(dateVal);
        }

        String dateStr = 'Unknown date';
        if (ts != null) {
          final dt = ts.toDate();
          dateStr = '${dt.day}/${dt.month}/${dt.year}';
        }

        loadedExpenses.add({
          'id': data['id'] ?? data['expenseId'] ?? '',
          'title': title,
          'amount': amt.toInt(),
          'rawAmount': amt,
          'category': category,
          'description': description,
          'date': dateStr,
          'timestamp': ts,
        });
      }

      loadedExpenses.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          allExpenses = loadedExpenses;
        });
      }
    } catch (e) {
      log("Error fetching expenses: $e");
    }
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: context.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: context.textTertiary,
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
      backgroundColor: context.appBackground,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: context.isDarkMode
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadAllData,
            color: context.textPrimary,
            backgroundColor: context.cardBackground,
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
                          ? '--'
                          : CurrencyFormatter.formatByCountryCompact(
                              _totalExpensesAmount,
                              _userCountryCode,
                            ),
                      style: GoogleFonts.inter(
                        color: context.textPrimary,
                        fontSize: 48,
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
                      color: context.textSecondary,
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
              color: context.glassBackgroundStrong,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Icon(Icons.arrow_back, color: context.iconPrimary, size: 20),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "Funds Overview",
              style: GoogleFonts.inter(
                color: context.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Capital Analysis",
              style: GoogleFonts.inter(
                color: context.textPrimary,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: context.isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
                      color: context.textSecondary,
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
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.iconSecondary,
                              ),
                            )
                          : Icon(
                              Icons.refresh,
                              color: context.iconSecondary,
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
              color: context.textSecondary,
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
                  ? '--'
                  : CurrencyFormatter.formatByCountryCompact(
                      _availableAmount,
                      _userCountryCode,
                    ),
              style: GoogleFonts.inter(
                color: context.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
            ),
          ),
          if (!isLoading &&
              _dataLoaded &&
              fundingAmount != null &&
              fundingAmount! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${((_availableAmount / fundingAmount!) * 100).toStringAsFixed(1)}% of total capital remaining',
                style: GoogleFonts.inter(
                  color: context.textSecondary,
                  fontSize: 13,
                ),
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
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
            boxShadow: context.isDarkMode
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                          Divider(color: context.borderColor, height: 1),
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
    final amount = (item['amount'] as num?)?.toInt() ?? 0;
    final isActive =
        item['status'] == 'active' || item['status'] == 'completed';

    final formattedAmount =
        '+${CurrencyFormatter.formatByCountryCompact(amount.toDouble(), _userCountryCode)}';

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
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item['date'] as String,
                style: GoogleFonts.inter(
                  color: context.textSecondary,
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
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
            boxShadow: context.isDarkMode
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                            Divider(color: context.borderColor, height: 1),
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
    final amount = (transaction['amount'] as num?)?.toInt() ?? 0;
    final isNegative = amount < 0;

    String formattedAmount;
    Color amountColor;

    final cleanAmount = CurrencyFormatter.formatByCountryCompact(
      amount.abs().toDouble(),
      _userCountryCode,
    );

    if (isNegative) {
      formattedAmount = '-$cleanAmount';
      amountColor = const Color(0xFFFF453A);
    } else {
      formattedAmount = '+$cleanAmount';
      amountColor = isActive ? const Color(0xFF30D158) : context.textPrimary;
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
                : context.glassBackgroundStrong,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExpense
                  ? const Color(0xFFFF453A).withValues(alpha: 0.3)
                  : isActive
                  ? const Color(0xFF30D158).withValues(alpha: 0.3)
                  : context.borderColor,
            ),
          ),
          child: Icon(
            isExpense
                ? Icons.receipt
                : (isActive ? Icons.trending_up : Icons.account_balance),
            color: isExpense
                ? const Color(0xFFFF453A)
                : (isActive ? const Color(0xFF30D158) : context.iconSecondary),
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
                  color: context.textPrimary,
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
                  color: context.textSecondary,
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

    final formattedOutflow = CurrencyFormatter.formatByCountryCompact(
      totalOutflow.abs().toDouble(),
      _userCountryCode,
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
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
            boxShadow: context.isDarkMode
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                    Divider(color: context.borderColor, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Outflow",
                          style: GoogleFonts.inter(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '-$formattedOutflow',
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

    final formattedAmount = CurrencyFormatter.formatByCountryCompact(
      amount.abs().toDouble(),
      _userCountryCode,
    );
    final displayAmount =
        isPositive ? '+$formattedAmount' : '-$formattedAmount';

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
                color: context.textSecondary,
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
                displayAmount,
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

  Widget _buildBankAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("PAYMENT METHODS"),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
            boxShadow: context.isDarkMode
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                            Divider(color: context.borderColor, height: 1),
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
        if (result != null) {
          _loadAllData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.glassBackgroundStrong,
          border: Border.all(color: context.borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: context.textPrimary, size: 16),
            const SizedBox(width: 8),
            Text(
              "Add Bank Account",
              style: GoogleFonts.inter(
                color: context.textPrimary,
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
    final totalSpent = (account['totalSpent'] as num?)?.toDouble() ?? 0.0;
    final isCash = account['isCash'] == true;

    final bankName =
        account['name']?.toString() ??
        account['bankName']?.toString() ??
        account['bank_name']?.toString() ??
        'Unknown Bank';

    final accentColor =
        isCash ? const Color(0xFFFF9F0A) : const Color(0xFF30D158);

    final cleanSpent = totalSpent
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
    final formattedAmount = totalSpent > 0
        ? '-${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}$cleanSpent'
        : '${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}0';

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            isCash ? Icons.payments_outlined : Icons.account_balance,
            color: accentColor,
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
                  color: context.textPrimary,
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
                  color: context.textSecondary,
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
                      : context.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "total transactions",
              style: GoogleFonts.inter(
                color: context.textSecondary,
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
