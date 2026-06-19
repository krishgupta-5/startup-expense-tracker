import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../services/currency_preference_service.dart';
import '../../../services/currency_formatter.dart';

class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingData = true;
  String _userCountryCode = '+1'; // Default to USD
  double _currentBudget = 0.0;

  final Map<String, String> _allCategories = {
    'marketing': 'Marketing',
    'infrastructure': 'Infrastructure',
    'office': 'Office Rent',
    'software': 'Software',
    'hardware': 'Hardware',
    'transport': 'Transport',
    'design': 'Design',
    'others': 'Others',
    'travel': 'Travel',
    'meals': 'Meals',
    'contractors': 'Contractors',
    'legal': 'Legal',
    'salaries': 'Salary',
  };

  // Default to the first specific category
  String _selectedCategory = 'marketing';

  @override
  void initState() {
    super.initState();
    _loadUserCountryCode();
    _loadCurrentBudget();

    // Listen for currency changes
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
  }

  @override
  void dispose() {
    _budgetController.dispose();
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

  Future<void> _loadUserCountryCode() async {
    final currencyCode = await CurrencyPreferenceService.getCurrencyPreference();
    if (mounted) {
      setState(() {
        _userCountryCode = currencyCode;
      });
    }
  }

  Future<void> _loadCurrentBudget() async {
    if (!mounted) return;
    setState(() => _isLoadingData = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user document to find companyId
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final companyId = userDoc.data()?['companyId'];
      if (companyId == null) return;

      // Load budget settings from company document
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (companyDoc.exists) {
        final companyData = companyDoc.data() as Map<String, dynamic>;
        final budgets = companyData['budgets'] as Map<String, dynamic>? ?? {};

        if (mounted) {
          setState(() {
            _currentBudget = DataHelpers.safeParseDouble(
              budgets[_selectedCategory] ?? 0.0,
            );
            // Pre-fill the controller with the current budget
            _budgetController.text = _currentBudget > 0
                ? _currentBudget.toStringAsFixed(2)
                : '';
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading budget: $e');
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
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

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user document to find companyId
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final companyId = userDoc.data()?['companyId'];
      if (companyId == null) return;

      final budgetAmount = double.tryParse(
        _budgetController.text.trim().replaceAll(RegExp(r'[^\d.]'), '')
      ) ?? 0.0;

      // Update budget in company document
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .update({
        'budgets.$_selectedCategory': budgetAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _currentBudget = budgetAmount;
          _isLoading = false;
        });

        _showMinimalToast('Budget updated successfully');
      }
    } catch (e) {
      debugPrint('Error saving budget: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showMinimalToast('Failed to update budget', isError: true);
      }
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
                child: _isLoadingData
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
                        ),
                      )
                    : GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 32),

                                // Category Selection
                                _buildSectionLabel("EXPENSE CATEGORY"),
                                _buildCategorySelector(),
                                const SizedBox(height: 32),

                                // Current Budget Display
                                _buildReadOnlyMetric(
                                  "CURRENT ALLOCATION",
                                  CurrencyFormatter.formatByCountry(
                                    _currentBudget,
                                    _userCountryCode,
                                  ),
                                  highlight: _currentBudget > 0,
                                ),
                                const SizedBox(height: 32),

                                // Budget Amount Input
                                _buildSectionLabel("UPDATE MONTHLY LIMIT"),
                                _buildAmountInput(currencySymbol),

                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              if (!_isLoadingData) _buildSubmitButton(),
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
            "Budget Settings",
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

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: double.infinity),
      // Removed outer container to eliminate the double box issue
      child: ShadSelect<String>(
        placeholder: Text(
          'Select category',
          style: GoogleFonts.inter(color: Colors.white24, fontSize: 15),
        ),
        initialValue: _selectedCategory,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedCategory = value;
              _budgetController.clear();
            });
            _loadCurrentBudget(); 
          }
        },
        selectedOptionBuilder: (context, value) {
          return Text(
            _allCategories[value] ?? 'Select category',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          );
        },
        options: _allCategories.entries.map((entry) {
          return ShadOption(
            value: entry.key,
            child: Text(
              entry.value,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            ),
          );
        }).toList(),
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
          // Refined padding to closely match the inputs
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                // Reduced from 20 to 18 to match standard elegant typography
                fontSize: 18, 
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput(String currencySymbol) {
    return Container(
      // Refined vertical padding to match the ReadOnlyMetric and Select
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), 
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            currencySymbol,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 18, // Normalized size 
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onTapOutside: (event) => FocusScope.of(context).unfocus(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18, // Normalized size
                fontWeight: FontWeight.w600,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: "0.00",
                hintStyle: GoogleFonts.inter(
                  color: Colors.white12,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                errorStyle: GoogleFonts.inter(
                  color: const Color(0xFFFF453A),
                  fontSize: 11,
                  height: 0.8,
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Amount required';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed < 0) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
          ),
        ],
      ),
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
          onPressed: _isLoading ? null : _saveBudget,
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
                  "Save Budget",
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

// Helper class for data parsing
class DataHelpers {
  static double safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}