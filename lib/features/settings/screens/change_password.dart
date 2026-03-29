import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  // State for visibility toggles
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Controllers
  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  // Validation States
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumberOrSymbol = false;

  @override
  void initState() {
    super.initState();
    // Listen to new password changes for dynamic validation
    _newPassController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _newPassController.removeListener(_validatePassword);
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final pass = _newPassController.text;
    setState(() {
      _hasMinLength = pass.length >= 8;
      _hasUppercase = pass.contains(RegExp(r'[A-Z]'));
      _hasNumberOrSymbol = pass.contains(RegExp(r'[0-9!@#\$&*~]'));
    });
  }

  // --- UNIFIED MINIMAL TOAST ---
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

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard

    final oldPass = _oldPassController.text.trim();
    final newPass = _newPassController.text.trim();
    final confirmPass = _confirmPassController.text.trim();

    // 1. Basic Validation
    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showMinimalToast("Please fill in all fields.", isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _showMinimalToast("New passwords do not match.", isError: true);
      return;
    }
    if (!_hasMinLength || !_hasUppercase || !_hasNumberOrSymbol) {
      _showMinimalToast(
        "New password does not meet all requirements.",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception("No authenticated user found.");
      }

      // 2. Re-authenticate User (Required before changing password)
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPass,
      );

      await user.reauthenticateWithCredential(credential);

      // 3. Update Password
      await user.updatePassword(newPass);

      if (mounted) {
        Navigator.pop(context);
        _showMinimalToast("Password updated successfully!");
      }
    } on FirebaseAuthException catch (e) {
      String message = "Failed to update password.";
      if (e.code == 'wrong-password') {
        message = "The current password you entered is incorrect.";
      } else if (e.code == 'weak-password') {
        message = "The new password provided is too weak.";
      } else {
        message = e.message ?? message;
      }
      _showMinimalToast(message, isError: true);
    } catch (e) {
      _showMinimalToast("An unexpected error occurred.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Premium Header
              _buildHeader(context),

              // 2. Scrollable Form
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

                        // Old Password
                        _buildSectionLabel("CURRENT PASSWORD"),
                        const SizedBox(height: 8),
                        _buildPasswordField(
                          controller: _oldPassController,
                          hint: "Enter current password",
                          obscureText: _obscureOld,
                          textInputAction: TextInputAction.next,
                          onToggle: () =>
                              setState(() => _obscureOld = !_obscureOld),
                        ),

                        const SizedBox(height: 32),

                        // New Password
                        _buildSectionLabel("NEW PASSWORD"),
                        const SizedBox(height: 8),
                        _buildPasswordField(
                          controller: _newPassController,
                          hint: "Enter new password",
                          obscureText: _obscureNew,
                          textInputAction: TextInputAction.next,
                          onToggle: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),

                        const SizedBox(height: 24),

                        // Confirm Password
                        _buildSectionLabel("CONFIRM NEW PASSWORD"),
                        const SizedBox(height: 8),
                        _buildPasswordField(
                          controller: _confirmPassController,
                          hint: "Re-enter new password",
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onToggle: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Password Requirements Box
                        _buildRequirements(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Update Button
              _buildSaveButton(),
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
                color: Colors.white.withValues(
                  alpha: 0.05,
                ), // White Glass Style
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          Text(
            "Change Password",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Spacer to balance layout
          const SizedBox(width: 44),
        ],
      ),
    );
  }

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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggle,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        textInputAction: textInputAction,
        onTapOutside: (event) => FocusScope.of(context).unfocus(),
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white24),
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: Colors.white38,
            size: 20,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.white38,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildRequirements() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel("PASSWORD REQUIREMENTS"),
          const SizedBox(height: 20),
          _buildRequirementRow("At least 8 characters", _hasMinLength),
          const SizedBox(height: 16),
          _buildRequirementRow("One uppercase character", _hasUppercase),
          const SizedBox(height: 16),
          _buildRequirementRow("One number or symbol", _hasNumberOrSymbol),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Row(
      children: [
        // Smooth scale animation when the requirement is met
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            key: ValueKey<bool>(isMet),
            color: isMet ? const Color(0xFF30D158) : Colors.white24,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        // Smooth color transition for the text
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: GoogleFonts.inter(
            color: isMet ? Colors.white : Colors.white54,
            fontSize: 13,
            fontWeight: isMet ? FontWeight.w500 : FontWeight.w400,
          ),
          child: Text(text),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
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
          onPressed: _isLoading ? null : _changePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white54,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  "Update Password",
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
