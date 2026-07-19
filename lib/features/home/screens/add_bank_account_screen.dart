import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_theme.dart';

class AddBankAccountScreen extends StatefulWidget {
  const AddBankAccountScreen({super.key});

  @override
  State<AddBankAccountScreen> createState() => _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends State<AddBankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  void _showMinimalToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError
                  ? const Color(0xFFFF453A)
                  : const Color(0xFF30D158),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: context.cardBackground,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.borderColor),
        ),
        duration: const Duration(seconds: 3),
        elevation: 0,
      ),
    );
  }

  Future<void> _saveBankAccount() async {
    // Dismiss keyboard on submit
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      // Add the new bank account to the 'Bank Accounts' array in Firestore
      await FirebaseFirestore.instance
          .collection("companies")
          .doc(user.uid)
          .update({
            "Bank Accounts": FieldValue.arrayUnion([
              {
                "name": _bankNameController.text.trim(),
                "number": _accountNumberController.text.trim(),
              },
            ]),
          });

      if (mounted) {
        _showMinimalToast("Bank account added successfully");
        // Return the bank account data for instant display in settings
        Navigator.pop(context, {
          "bankName": _bankNameController.text.trim(),
          "last4": _accountNumberController.text.trim().length >= 4
              ? _accountNumberController.text.trim().substring(
                  _accountNumberController.text.trim().length - 4,
                )
              : _accountNumberController.text.trim(),
        });
      }
    } catch (e) {
      if (mounted) {
        _showMinimalToast("Error adding bank account", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: context.isDarkMode
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Premium Header
              _buildHeader(context),

              // 2. Scrollable Form
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // Badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF30D158,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: const Color(
                                    0xFF30D158,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                "NEW ACCOUNT",
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF30D158),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Inputs
                        _buildTextInput(
                          controller: _bankNameController,
                          label: "BANK NAME",
                          hint: "e.g., HDFC Bank, Chase",
                          icon: Icons.account_balance_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Bank name is required';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        _buildTextInput(
                          controller: _accountNumberController,
                          label: "ACCOUNT NUMBER",
                          hint: "Enter account number",
                          icon: Icons.numbers,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Account number is required';
                            }
                            if (value.trim().length < 8) {
                              return 'Account number must be at least 8 digits';
                            }
                            if (value.trim().length > 18) {
                              return 'Account number must be at most 18 digits';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Bottom Sticky Action Button
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
                color: context.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              child: Icon(
                Icons.arrow_back,
                color: context.textPrimary,
                size: 20,
              ),
            ),
          ),
          Text(
            "Add Bank Account",
            style: GoogleFonts.inter(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 44), // Balances header alignment
        ],
      ),
    );
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

  Widget _buildTextInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.done,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onTapOutside: (event) => FocusScope.of(context).unfocus(),
            style: GoogleFonts.inter(color: context.textPrimary, fontSize: 15),
            cursorColor: context.textPrimary,
            decoration: InputDecoration(
              icon: Icon(icon, color: context.iconSecondary, size: 20),
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: context.textTertiary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              errorStyle: GoogleFonts.inter(
                color: const Color(0xFFFF453A),
                fontSize: 12,
                height: 0.8,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final btnBg = context.isDarkMode ? Colors.white : Colors.black;
    final btnText = context.isDarkMode ? Colors.black : Colors.white;
    final disabledBg = context.isDarkMode ? Colors.white54 : Colors.black38;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appBackground,
        border: Border(
          top: BorderSide(color: context.borderColor),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveBankAccount,
          style: ElevatedButton.styleFrom(
            backgroundColor: btnBg,
            foregroundColor: btnText,
            disabledBackgroundColor: disabledBg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: btnText,
                  ),
                )
              : Text(
                  "Link Bank Account",
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
