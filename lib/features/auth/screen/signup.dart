import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup_expense_tracker/features/auth/services/google_sign_in_service.dart';
import 'package:startup_expense_tracker/features/company-setup/screen/company_setup_screen.dart';
import 'package:startup_expense_tracker/services/ai_service.dart';
import 'package:startup_expense_tracker/shared/utils/error_handler.dart';

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

  Future<bool> _verifyEmail(String email) async {
    try {
      final apiKey = dotenv.env['APILAYER_EMAIL_ACCESS_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('Error: APILAYER_EMAIL_ACCESS_KEY is missing in .env.local');
        return true; 
      }

      final encodedEmail = Uri.encodeComponent(email);
      final url = Uri.parse('https://apilayer.net/api/check?access_key=$apiKey&email=$encodedEmail');

      final response = await http.get(url, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('error')) {
          debugPrint('APILayer Error: ${data['error']['info']}');
          return true; 
        }

        final bool isFormatValid = data['format_valid'] == true;
        final bool isMxFound = data['mx_found'] == true;
        final bool isDisposable = data['disposable'] == true;
        final bool isSmtpValid = data['smtp_check'] == true; 
        final double score = (data['score'] ?? 0.0).toDouble();

        return isFormatValid && 
               isMxFound && 
               !isDisposable && 
               isSmtpValid && 
               score > 0.6;
      }
      return false;
    } catch (e) {
      debugPrint('Email validation exception: $e');
      return true; 
    }
  }

  Future<void> createUserWithEmailAndPassword() async {
    FocusScope.of(context).unfocus(); 
    
    final email = _emailController.text.trim();
    
    if (!email.contains('@') || email.isEmpty) {
      ErrorHandler.handleValidationError(
        context: context,
        field: 'Email',
        validationMessage: 'Enter a valid email',
      );
      return;
    }

    final password = _passwordController.text.trim();
    if (password.length < 8 ||
        !password.contains(RegExp(r'[A-Z]')) ||
        !password.contains(RegExp(r'[0-9]'))) {
      ErrorHandler.handleValidationError(
        context: context,
        field: 'Password',
        validationMessage: 'Use 8+ chars, 1 uppercase, 1 number',
      );
      return;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ErrorHandler.handleValidationError(
        context: context,
        field: 'Password',
        validationMessage: 'Passwords do not match',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final isEmailActiveAndValid = await _verifyEmail(email);
    
    if (!isEmailActiveAndValid) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ErrorHandler.handleValidationError(
          context: context,
          field: 'Email',
          validationMessage: 'Please enter a valid, active real email address.',
        );
      }
      return; 
    }

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

      final User? user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'provider': 'email',
          'companySetup': false, 
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        AIService.syncAICollections().catchError((e) {
          debugPrint("Failed to sync AI data after signup: $e");
        });

        if (mounted) {
          ErrorHandler.handleSuccess(
            context: context,
            message: 'Account created successfully! Welcome to our platform.',
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const CompanySetupScreen()),
          );
        }
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // --- FIXED: MODERN WAY TO CHECK FOR DUPLICATE PROVIDER EMAILS ---
      if (e.code == 'email-already-in-use') {
        ErrorHandler.handleValidationError(
          context: context,
          field: 'Email',
          validationMessage: 'This email is already registered (Google or Email). Please log in instead.',
        );
      } else {
        ErrorHandler.handleAuthError(
          context: context,
          error: e,
          onRetry: createUserWithEmailAndPassword,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      ErrorHandler.handleError(
        context: context,
        error: e,
        customMessage:
            'An error occurred while creating your account. Please try again.',
        onRetry: createUserWithEmailAndPassword,
      );
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
      backgroundColor: const Color(0xFF09090B),
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).viewInsets.bottom -
                      MediaQuery.of(context).padding.top,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildLabel("EMAIL ADDRESS"),
                      const SizedBox(height: 8),
                      _buildInputField(
                        controller: _emailController,
                        hint: "name@company.com",
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel("PASSWORD"),
                      const SizedBox(height: 8),
                      _buildPasswordField(),
                      const SizedBox(height: 20),
                      _buildLabel("CONFIRM PASSWORD"),
                      const SizedBox(height: 8),
                      _buildConfirmPasswordField(),
                      const SizedBox(height: 24),
                      _buildSignUpButton(),
                      const SizedBox(height: 24),
                      _buildDivider(),
                      const SizedBox(height: 16),
                      _buildGoogleSignInButton(),
                      const Spacer(),
                      _buildFooter(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ), 
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
            color: Colors.white70, 
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
        color: Colors.white70, 
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ), 
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: Colors.white38,
          ), 
          icon: Icon(
            icon,
            color: Colors.white60,
            size: 20,
          ), 
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ), 
      ),
      child: TextField(
        controller: _confirmPasswordController,
        obscureText: !_isConfirmPasswordVisible,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: "Confirm your password",
          hintStyle: GoogleFonts.inter(
            color: Colors.white38,
          ), 
          icon: const Icon(
            Icons.lock_outline,
            color: Colors.white60,
            size: 20,
          ), 
          suffixIcon: IconButton(
            icon: Icon(
              _isConfirmPasswordVisible
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: Colors.white60, 
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ), 
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: "Create a password",
          hintStyle: GoogleFonts.inter(
            color: Colors.white38,
          ), 
          icon: const Icon(
            Icons.lock_outline,
            color: Colors.white60,
            size: 20,
          ), 
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.white60, 
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
          disabledBackgroundColor: Colors.white70, 
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24, 
                width: 24,
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
                  color: Colors.black, 
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Or",
            style: GoogleFonts.inter(
              color: Colors.white60, 
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    return GestureDetector(
      onTap: () async {
        if (_isLoading) return;

        setState(() {
          _isLoading = true;
        });

        try {
          final UserCredential? userCredential =
              await GoogleSignInService.signInWithGoogle();

          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            if (userCredential != null) {
              final bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
              final User user = userCredential.user!;

              if (isNewUser) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                  'uid': user.uid,
                  'email': user.email ?? '',
                  'provider': 'google',
                  'companySetup': false, 
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                AIService.syncAICollections().catchError((e) {
                  debugPrint("Failed to sync AI data after Google sign-up: $e");
                });

                if (mounted) {
                  ErrorHandler.handleSuccess(
                    context: context,
                    message: 'Account created successfully! Welcome.',
                  );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const CompanySetupScreen()),
                  );
                }
              } else {
                AIService.syncAICollections().catchError((e) {
                  debugPrint("Failed to sync AI data after Google sign-in: $e");
                });

                if (mounted) {
                  ErrorHandler.handleSuccess(
                    context: context,
                    message: 'Welcome back! Logging you in.',
                  );
                }
              }
            } else {
              ErrorHandler.handleAuthError(
                context: context,
                error: FirebaseAuthException(
                  code: 'invalid-credential',
                  message: 'Google sign-in was cancelled or failed.',
                ),
                onRetry: () async {},
              );
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            ErrorHandler.handleError(
              context: context,
              error: e,
              customMessage: 'Failed to sign in with Google. Please try again.',
              onRetry: () async {},
            );
          }
        }
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ), 
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
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 14,
          ), 
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
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