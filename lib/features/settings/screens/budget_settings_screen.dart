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

  // Removed 'all' - only specific allocatable categories remain
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
    final currencyCode =
        await CurrencyPreferenceService.getCurrencyPreference();
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

      final budgetAmount = double.tryParse(_budgetController.text) ?? 0.0;

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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Budget updated successfully',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFF30D158),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving budget: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update budget',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFFFF453A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF09090B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF09090B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Budget Settings',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: _isLoadingData
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Selection
                      Text(
                        'Expense Category',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: double.infinity,
                        ),
                        child: ShadSelect<String>(
                          placeholder: const Text('Select category'),
                          initialValue: _selectedCategory,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCategory = value;
                                _budgetController.clear();
                              });
                              _loadCurrentBudget(); // Fetch the newly selected category's budget
                            }
                          },
                          selectedOptionBuilder: (context, value) {
                            return Text(
                              _allCategories[value] ?? 'Select category',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            );
                          },
                          options: _allCategories.entries.map((entry) {
                            return ShadOption(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: GoogleFonts.inter(color: Colors.white),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Budget Input
                      Text(
                        'Monthly Budget',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: TextFormField(
                          controller: _budgetController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            prefixText: CurrencyFormatter.getCurrencySymbol(
                              _userCountryCode,
                            ),
                            prefixStyle: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                            hintText: '0.00',
                            hintStyle: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a budget amount';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null || amount < 0) {
                              return 'Please enter a valid amount';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Current Budget Display
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _currentBudget >= 0
                            ? Container(
                                key: ValueKey<double>(_currentBudget),
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF30D158,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF30D158,
                                    ).withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: Color(0xFF30D158),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Currently Allocated: ${CurrencyFormatter.getCurrencySymbol(_userCountryCode)}${_currentBudget.toStringAsFixed(2)}',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF30D158),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveBudget,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A84FF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: const Color(
                              0xFF0A84FF,
                            ).withValues(alpha: 0.5),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Save Budget',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
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

  static String safeParseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}
