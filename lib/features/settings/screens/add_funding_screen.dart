import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'dart:math'; // Added for the shake sine wave math

import '../../../services/currency_formatter.dart';
import '../../../services/user_country_service.dart';
import '../../../services/financial_calculator.dart';

class AddFundingScreen extends StatefulWidget {
  const AddFundingScreen({super.key});

  @override
  State<AddFundingScreen> createState() => _AddFundingScreenState();
}

// Added SingleTickerProviderStateMixin for the AnimationController
class _AddFundingScreenState extends State<AddFundingScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _targetRunwayController = TextEditingController();

  // Bank Loan controllers & state
  final TextEditingController _lenderBankController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _tenureController = TextEditingController();
  final TextEditingController _emiController = TextEditingController();
  String _loanRateType = 'reducing'; // 'flat' or 'reducing'
  bool _userEditedEmi = false;
  DateTime _selectedEmiDate = DateTime.now().add(const Duration(days: 30));

  bool _isLoading = false;
  bool _updateTargetRunway = false;
  String _selectedSource = 'self_funded';
  String _userCountryCode = '+1';

  // Current funding & target runway from Firestore
  double _currentFunding = 0.0;
  double _inputAmount = 0.0;
  String _currentTargetRunway = '';

  // --- Animation & Validation State ---
  late AnimationController _shakeController;
  final Set<String> _errorFields = {}; // Tracks which fields failed validation

  // Re-introduced elegant, premium colors and icons for the selectable chips
  final Map<String, Map<String, dynamic>> _fundingSources = {
    'self_funded': {
      'label': 'Self Funded',
      'icon': Icons.person_outline,
      'color': const Color(0xFF30D158), // Green
    },
    'bank_loan': {
      'label': 'Bank Loan',
      'icon': Icons.account_balance_outlined,
      'color': const Color(0xFF0A84FF), // iOS Blue
    },
    'angel_investor': {
      'label': 'Angel Investor',
      'icon': Icons.favorite_outline,
      'color': const Color(0xFFFF375F), // Rose Pink
    },
    'vc_funding': {
      'label': 'VC Funding',
      'icon': Icons.rocket_launch_outlined,
      'color': const Color(0xFFFF9F0A), // Sunset Orange
    },
    'grant': {
      'label': 'Grant',
      'icon': Icons.workspace_premium_outlined,
      'color': const Color(0xFF32ADE6), // Cyan
    },
    'revenue': {
      'label': 'Revenue',
      'icon': Icons.trending_up,
      'color': const Color(0xFF00BFA5), // Teal
    },
    'other': {
      'label': 'Other',
      'icon': Icons.more_horiz,
      'color': const Color(0xFF8E8E93), // Slate Gray
    },
  };

  @override
  void initState() {
    super.initState();
    _userCountryCode = UserCountryService.getUserCountryCodeSync();
    _loadCurrentData();

    // Initialize the shake animation controller
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Listen to amount changes for real-time projection
    _amountController.addListener(() {
      setState(() {
        _inputAmount = double.tryParse(
              _amountController.text.replaceAll(RegExp(r'[^\d.]'), ''),
            ) ??
            0.0;
      });
      if (_selectedSource == 'bank_loan') {
        _recalculateEmi();
      }
    });

    _interestController.addListener(() {
      if (_selectedSource == 'bank_loan') {
        _recalculateEmi();
      }
    });

    _tenureController.addListener(() {
      if (_selectedSource == 'bank_loan') {
        _recalculateEmi();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _targetRunwayController.dispose();
    _interestController.dispose();
    _tenureController.dispose();
    _emiController.dispose();
    _lenderBankController.dispose();
    super.dispose();
  }

  void _recalculateEmi() {
    if (_userEditedEmi) return;

    final principal = _inputAmount;
    final rate = double.tryParse(_interestController.text) ?? 0.0;
    final tenure = int.tryParse(_tenureController.text) ?? 0;

    double emi = 0.0;
    if (_loanRateType == 'flat') {
      emi = FinancialCalculator.calculateFlatRateEmi(principal, rate, tenure);
    } else {
      emi = FinancialCalculator.calculateReducingRateEmi(principal, rate, tenure);
    }

    if (emi > 0) {
      _emiController.text = emi.toStringAsFixed(2);
    } else {
      _emiController.text = '';
    }
  }


  Future<void> _loadCurrentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _currentFunding = _toDouble(
            data['Funding'] ?? data['funding'] ?? 0,
          );
          _currentTargetRunway = data['Target Runway']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading current data: $e');
    }
  }

  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^\d.-]'), '')) ?? fallback;
    }
    return fallback;
  }

  void _showMinimalToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? const Color(0xFFFF453A) : const Color(0xFF30D158),
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

  Future<void> _validateAndSaveFunding() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _errorFields.clear();
      // Check mandatory fields
      if (_inputAmount <= 0) _errorFields.add("ADD FUNDING AMOUNT");
      if (_notesController.text.trim().isEmpty) _errorFields.add("NOTES");

      if (_selectedSource == 'bank_loan') {
        final rateVal = double.tryParse(_interestController.text) ?? 0.0;
        final tenureVal = int.tryParse(_tenureController.text) ?? 0;
        final emiVal = double.tryParse(_emiController.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

        if (_lenderBankController.text.trim().isEmpty) _errorFields.add("LENDER BANK NAME");
        if (rateVal <= 0) _errorFields.add("INTEREST RATE (% P.A.)");
        if (tenureVal <= 0) _errorFields.add("TENURE (MONTHS)");
        if (emiVal <= 0) _errorFields.add("EMI AMOUNT");
      }
    });

    if (_errorFields.isNotEmpty) {
      // Trigger the shake animation from 0 to 1
      _shakeController.forward(from: 0.0);
      _showMinimalToast("Please fill out all required fields", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final amount = _inputAmount;
      final sourceData = _fundingSources[_selectedSource]!;
      final sourceLabel = sourceData['label'] as String;
      final newTotalFunding = _currentFunding + amount;
      final now = DateTime.now();

      final isBankLoan = _selectedSource == 'bank_loan';
      final loanLenderBank = isBankLoan ? _lenderBankController.text.trim() : null;
      final loanInterestRate = isBankLoan ? (double.tryParse(_interestController.text) ?? 0.0) : null;
      final loanRateType = isBankLoan ? _loanRateType : null;
      final loanTenureMonths = isBankLoan ? (int.tryParse(_tenureController.text) ?? 0) : null;
      final loanEmiAmount = isBankLoan ? (double.tryParse(_emiController.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0) : null;

      // 1. Save the funding transaction
      await FirebaseFirestore.instance.collection('funding_transactions').add({
        'uid': user.uid,
        'amount': amount,
        'source': sourceLabel,
        'sourceKey': _selectedSource,
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'previousFunding': _currentFunding,
        'newTotalFunding': newTotalFunding,
        if (isBankLoan) ...{
          'isBankLoan': true,
          'loanLenderBank': loanLenderBank,
          'loanInterestRate': loanInterestRate,
          'loanRateType': loanRateType,
          'loanTenureMonths': loanTenureMonths,
          'loanEmiAmount': loanEmiAmount,
          'loanEmiStartDate': Timestamp.fromDate(_selectedEmiDate),
        }
      });

      // 2. Create an expense transaction
      final expenseId = const Uuid().v4();
      await FirebaseFirestore.instance.collection('expenses').doc(expenseId).set({
        'uid': user.uid,
        'Amount': amount,
        'Title': 'Funding: $sourceLabel',
        'Description': _notesController.text.trim(),
        'Date': Timestamp.fromDate(now),
        'Category': 'funding',
        'Type': 'one_time',
        'BankAccount': null,
        'AttachmentFileId': '',
        'ExpenseType': 'funding',
        'isFunding': true,
        'fundingSource': sourceLabel,
        'fundingSourceKey': _selectedSource,
        'Time': FieldValue.serverTimestamp(),
        if (isBankLoan) ...{
          'isBankLoan': true,
          'loanLenderBank': loanLenderBank,
          'loanInterestRate': loanInterestRate,
          'loanRateType': loanRateType,
          'loanTenureMonths': loanTenureMonths,
          'loanEmiAmount': loanEmiAmount,
          'loanEmiStartDate': Timestamp.fromDate(_selectedEmiDate),
        }
      });

      // 3. If it's a bank loan, automatically create a recurring expense for the EMI repayments
      if (isBankLoan && loanEmiAmount != null && loanEmiAmount > 0) {
        final emiExpenseId = const Uuid().v4();
        final String companyId = user.uid;

        await FirebaseFirestore.instance.collection('expenses').doc(emiExpenseId).set({
          'uid': user.uid,
          'companyId': companyId,
          'Amount': loanEmiAmount,
          'Title': 'EMI: $loanLenderBank Loan Repayment',
          'Description': 'Monthly EMI repayment for $loanLenderBank loan of amount $amount',
          'Date': Timestamp.fromDate(_selectedEmiDate),
          'Category': 'others',
          'Type': 'recurring',
          'BankAccount': null,
          'AttachmentFileId': '',
          'ExpenseType': 'others',
          'isFunding': false,
          'isEmiRepayment': true,
          'loanLenderBank': loanLenderBank,
          'loanInterestRate': loanInterestRate,
          'loanRateType': loanRateType,
          'loanTenureMonths': loanTenureMonths,
          'loanEmiStartDate': Timestamp.fromDate(_selectedEmiDate),
          'Time': FieldValue.serverTimestamp(),
        });
      }

      // 4. Update the total Funding in companies collection
      final Map<String, dynamic> updateData = {
        'Funding': newTotalFunding,
      };

      if (_updateTargetRunway && _targetRunwayController.text.trim().isNotEmpty) {
        updateData['Target Runway'] = _targetRunwayController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      if (mounted) {
        _showMinimalToast("Funding added successfully!");
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showMinimalToast(
          "Error adding funding: ${e.toString()}",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = CurrencyFormatter.getCurrencySymbol(_userCountryCode);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),

                        // Current & Projected Funding
                        Row(
                          children: [
                            Expanded(
                              child: _buildReadOnlyMetric(
                                "CURRENT FUNDING",
                                CurrencyFormatter.formatByCountry(
                                  _currentFunding,
                                  _userCountryCode,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildReadOnlyMetric(
                                "NEW TOTAL",
                                CurrencyFormatter.formatByCountry(
                                  _currentFunding + _inputAmount,
                                  _userCountryCode,
                                ),
                                highlight: _inputAmount > 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Amount input (Animated internally)
                        _buildAmountInput(currencySymbol),
                        const SizedBox(height: 40),

                        // Source selector
                        _buildSectionLabel("FUNDING SOURCE"),
                        _buildSourceSelector(),
                        const SizedBox(height: 40),

                        // Bank Loan Details Section
                        _buildBankLoanDetailsSection(),

                        // Notes (Animated internally)
                        _buildInputGroup(
                          "NOTES",
                          "e.g., Seed round from XYZ Ventures",
                          _notesController,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 40),

                        // Target Runway toggle
                        _buildSectionLabel("PLANNING"),
                        _buildTargetRunwaySection(),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          Text(
            "Add Funding",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, {bool hasError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: hasError ? const Color(0xFFFF453A) : Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildReadOnlyMetric(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: highlight ? const Color(0xFF30D158) : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight 
                ? const Color(0xFF30D158).withValues(alpha: 0.3) 
                : Colors.white.withValues(alpha: 0.04)
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: highlight ? const Color(0xFF30D158) : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput(String currencySymbol) {
    final String label = "ADD FUNDING AMOUNT";
    final bool hasError = _errorFields.contains(label);

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final offset = hasError ? sin(_shakeController.value * 3 * pi) * 8 : 0.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(label, hasError: hasError),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: hasError 
                  ? const Color(0xFFFF453A).withValues(alpha: 0.05) 
                  : const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasError 
                    ? const Color(0xFFFF453A).withValues(alpha: 0.5) 
                    : Colors.white.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  currencySymbol,
                  style: GoogleFonts.inter(
                    color: hasError ? const Color(0xFFFF453A) : Colors.white38,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    onTapOutside: (event) => FocusScope.of(context).unfocus(),
                    onChanged: (_) {
                      if (hasError) {
                        setState(() => _errorFields.remove(label));
                      }
                    },
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                    cursorColor: hasError ? const Color(0xFFFF453A) : Colors.white,
                    decoration: InputDecoration(
                      hintText: "0",
                      hintStyle: GoogleFonts.inter(
                        color: hasError ? const Color(0xFFFF453A).withValues(alpha: 0.5) : Colors.white12,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _fundingSources.entries.map((entry) {
        final key = entry.key;
        final data = entry.value;
        final isSelected = _selectedSource == key;
        final color = data['color'] as Color;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedSource = key;
              if (key != 'bank_loan') {
                _userEditedEmi = false;
                _lenderBankController.clear();
                _interestController.clear();
                _tenureController.clear();
                _emiController.clear();
              } else {
                _recalculateEmi();
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.1)
                  : const Color(0xFF141416),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.04),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data['icon'] as IconData,
                  color: isSelected ? color : Colors.white24,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  data['label'] as String,
                  style: GoogleFonts.inter(
                    color: isSelected ? color : Colors.white54,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBankLoanDetailsSection() {
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_outlined,
                    color: Color(0xFF0A84FF),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "LOAN DETAILS",
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0A84FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Lender Bank Name Field
              _buildBankLoanInputField(
                "LENDER BANK NAME",
                "e.g. HDFC Bank, Chase, etc.",
                _lenderBankController,
                isText: true,
              ),
              const SizedBox(height: 20),

              // EMI Date Selector Row
              _buildEmiDatePickerRow(),
              const SizedBox(height: 20),

              // Rate & Rate type Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildBankLoanInputField(
                      "INTEREST RATE (% P.A.)",
                      "e.g. 10.5",
                      _interestController,
                      isDouble: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMiniSectionLabel("RATE TYPE"),
                        const SizedBox(height: 8),
                        _buildRateTypeSelector(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Tenure & EMI Amount Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildBankLoanInputField(
                      "TENURE (MONTHS)",
                      "e.g. 24",
                      _tenureController,
                      isInteger: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBankLoanInputField(
                      "EMI AMOUNT",
                      "Auto-calculated",
                      _emiController,
                      isDouble: true,
                      onChanged: (val) {
                        setState(() {
                          _userEditedEmi = true;
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_userEditedEmi) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _userEditedEmi = false;
                        _recalculateEmi();
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF0A84FF)),
                    label: Text(
                      "Reset to calculated EMI",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0A84FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      crossFadeState: _selectedSource == 'bank_loan'
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildMiniSectionLabel(String text) {
    final bool hasError = _errorFields.contains(text);
    return Text(
      text,
      style: GoogleFonts.inter(
        color: hasError ? const Color(0xFFFF453A) : Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildBankLoanInputField(
    String label,
    String hint,
    TextEditingController controller, {
    bool isInteger = false,
    bool isDouble = false,
    bool isText = false,
    ValueChanged<String>? onChanged,
  }) {
    final bool hasError = _errorFields.contains(label);

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final offset = hasError ? sin(_shakeController.value * 3 * pi) * 8 : 0.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMiniSectionLabel(label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: hasError
                  ? const Color(0xFFFF453A).withValues(alpha: 0.05)
                  : const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError
                    ? const Color(0xFFFF453A).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.04),
              ),
            ),
            child: TextField(
              controller: controller,
              keyboardType: isText ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) {
                if (hasError) {
                  setState(() => _errorFields.remove(label));
                }
                if (onChanged != null) {
                  onChanged(val);
                }
              },
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: hasError ? const Color(0xFFFF453A) : Colors.white,
              inputFormatters: [
                if (isInteger) FilteringTextInputFormatter.digitsOnly,
                if (isDouble) FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                  color: Colors.white24,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateTypeSelector() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRateTypeButton('reducing', 'Reducing'),
          ),
          Expanded(
            child: _buildRateTypeButton('flat', 'Flat / Fixed'),
          ),
        ],
      ),
    );
  }

  Widget _buildRateTypeButton(String type, String label) {
    final isSelected = _loanRateType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _loanRateType = type;
          _recalculateEmi();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF141416) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: isSelected
              ? Border.all(color: Colors.white.withValues(alpha: 0.04))
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? const Color(0xFF0A84FF) : Colors.white38,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmiDatePickerRow() {
    final formattedDate = "${_selectedEmiDate.day}/${_selectedEmiDate.month}/${_selectedEmiDate.year}";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMiniSectionLabel("EMI REPAYMENT START DATE"),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showEmiDatePicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formattedDate,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.edit_outlined,
                  color: Colors.white38,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEmiDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEmiDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF0A84FF),
              onPrimary: Colors.black,
              surface: Color(0xFF141416),
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0A84FF),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedEmiDate) {
      setState(() {
        _selectedEmiDate = picked;
      });
    }
  }

  Widget _buildInputGroup(
    String label,
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    final bool hasError = _errorFields.contains(label);

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final offset = hasError ? sin(_shakeController.value * 3 * pi) * 8 : 0.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(label, hasError: hasError),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: hasError
                  ? const Color(0xFFFF453A).withValues(alpha: 0.05)
                  : const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasError
                    ? const Color(0xFFFF453A).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.04),
              ),
            ),
            child: TextField(
              controller: controller,
              keyboardType: isNumber ? TextInputType.number : TextInputType.text,
              maxLines: maxLines,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              onChanged: (_) {
                if (hasError) {
                  setState(() => _errorFields.remove(label));
                }
              },
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: hasError ? const Color(0xFFFF453A) : Colors.white,
              decoration: InputDecoration(
                hintText: hasError ? "This field is required" : hint,
                hintStyle: GoogleFonts.inter(
                  color: hasError
                      ? const Color(0xFFFF453A).withValues(alpha: 0.5)
                      : Colors.white24,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetRunwaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _updateTargetRunway = !_updateTargetRunway),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Update Target Runway",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Current Target: ${_currentTargetRunway.isNotEmpty ? '$_currentTargetRunway months' : 'Not set'}",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: _updateTargetRunway
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: _updateTargetRunway
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _updateTargetRunway ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Target Runway Input (animated)
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetRunwayController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: Colors.white,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: "Enter months (e.g., 18)",
                        hintStyle: GoogleFonts.inter(
                          color: Colors.white24,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  Text(
                    "months",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          crossFadeState: _updateTargetRunway
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }


  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _validateAndSaveFunding, // Hooked up the new trigger
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.2),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Text(
                  "Add Funding",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}