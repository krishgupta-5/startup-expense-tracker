import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup_expense_tracker/features/company-setup/screen/company_setup_screen.dart';
import 'package:startup_expense_tracker/features/auth/services/google_sign_in_service.dart';
import 'login.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Future<void> createUserWithEmailAndPassword() async {
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final User? user = userCredential.user;
      if (user != null) {
        // Create Firestore user document
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'provider': 'email',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
      }

      if (!mounted) return;

      // Navigate to company setup for new users
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CompanySetupScreen()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Sign up failed'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Spacer
                  const SizedBox(height: 24),

                  // 2. Header
                  _buildHeader(),

                  const SizedBox(height: 24),

                  // 3. Sign Up Form
                  // Email
                  _buildLabel("EMAIL ADDRESS"),
                  const SizedBox(height: 8),
                  _buildInputField(
                    controller: _emailController,
                    hint: "name@company.com",
                    icon: Icons.email_outlined,
                  ),

                  const SizedBox(height: 20),

                  // Password
                  _buildLabel("PASSWORD"),
                  const SizedBox(height: 8),
                  _buildPasswordField(),

                  const SizedBox(height: 20),

                  // Confirm Password
                  _buildLabel("CONFIRM PASSWORD"),
                  const SizedBox(height: 8),
                  _buildConfirmPasswordField(),

                  const SizedBox(height: 24),

                  // 4. Sign Up Button
                  _buildSignUpButton(),

                  const SizedBox(height: 24),

                  // 5. Divider
                  _buildDivider(),

                  const SizedBox(height: 16),

                  // 6. Google Sign Up (Single Button)
                  _buildGoogleSignInButton(),

                  const SizedBox(height: 16),

                  // 7. Login Footer
                  _buildFooter(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back Button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Create Account",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Join us to manage your startup finances.",
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: Colors.white24,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
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
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white12),
          icon: Icon(icon, color: Colors.white38, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: TextField(
        controller: _confirmPasswordController,
        obscureText: !_isConfirmPasswordVisible,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: "Confirm your password",
          hintStyle: GoogleFonts.inter(color: Colors.white12),
          icon: const Icon(Icons.lock_outline, color: Colors.white38, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _isConfirmPasswordVisible
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: Colors.white38,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              });
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: "Create a password",
          hintStyle: GoogleFonts.inter(color: Colors.white12),
          icon: const Icon(Icons.lock_outline, color: Colors.white38, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.white38,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () {
                createUserWithEmailAndPassword();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : Text(
                "Sign Up",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.04))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Or",
            style: GoogleFonts.inter(
              color: Colors.white24,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.04))),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    return GestureDetector(
      onTap: () async {
        setState(() {
          _isLoading = true;
        });

        final UserCredential? userCredential =
            await GoogleSignInService.signInWithGoogle();

        setState(() {
          _isLoading = false;
        });

        if (userCredential != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CompanySetupScreen()),
          );
        }
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/google_logo.png', height: 24, width: 24),
            const SizedBox(width: 12),
            const Text(
              "Google Sign-In",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          child: Text(
            "Login",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
