import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup_expense_tracker/features/auth/screen/signup.dart';
import 'package:startup_expense_tracker/features/auth/screen/forget_password.dart';
import 'package:startup_expense_tracker/features/auth/services/google_sign_in_service.dart';
import 'package:startup_expense_tracker/services/ai_service.dart';
import 'package:startup_expense_tracker/shared/utils/error_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> loginUserWithEmailAndPassword() async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard

    final email = _emailController.text.trim();

    // Email validation
    if (!email.contains('@')) {
      ErrorHandler.handleValidationError(
        context: context,
        field: 'Email',
        validationMessage: 'Enter a valid email',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // Show success message
      if (mounted) {
        ErrorHandler.handleSuccess(
          context: context,
          message: 'Login successful! Welcome back.',
        );
      }

      // Sync AI collections in background after successful login
      AIService.syncAICollections().catchError((e) {
        print("Failed to sync AI data after login: $e");
      });

      // Do nothing, AuthWrapper will handle navigation
    } on FirebaseAuthException catch (e) {
      ErrorHandler.handleAuthError(
        context: context,
        error: e,
        onRetry: loginUserWithEmailAndPassword,
      );
    } catch (e) {
      ErrorHandler.handleError(
        context: context,
        error: e,
        customMessage: 'An error occurred while logging in. Please try again.',
        onRetry: loginUserWithEmailAndPassword,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
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
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).viewInsets.bottom -
                      MediaQuery.of(context).padding.top,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),

                      // Header
                      _buildHeader(),
                      const SizedBox(height: 48),

                      // Login Form
                      _buildLabel("EMAIL ADDRESS"),
                      const SizedBox(height: 8),
                      _buildInputField(
                        controller: _emailController,
                        hint: "name@company.com",
                        action: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 24),

                      _buildLabel("PASSWORD"),
                      const SizedBox(height: 8),
                      _buildPasswordField(),

                      const SizedBox(height: 16),

                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Forgot Password?",
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Login Button
                      _buildLoginButton(),

                      const SizedBox(height: 40),

                      // Divider
                      _buildDivider(),

                      const SizedBox(height: 32),

                      // Google Sign In
                      _buildGoogleSignInButton(),

                      const Spacer(),

                      // Sign Up Footer
                      _buildFooter(context),
                      const SizedBox(height: 24),
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

  // --- WIDGET BUILDERS ---

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome Back",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Sign in to access your dashboard.",
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
    TextInputAction action = TextInputAction.next,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        textInputAction: action,
        keyboardType: keyboardType,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 4,
          ),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        textInputAction: TextInputAction.done,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: "Enter your password",
          hintStyle: GoogleFonts.inter(color: Colors.white38),
          // Text-based toggle instead of icon
          suffixIcon: GestureDetector(
            onTap: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
            child: Container(
              alignment: Alignment.center,
              width: 60,
              color: Colors.transparent,
              child: Text(
                _isPasswordVisible ? "HIDE" : "SHOW",
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : loginUserWithEmailAndPassword,
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
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : Text(
                "Login",
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
            "Or continue with",
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
              // Sync AI collections in background after successful Google sign-in
              AIService.syncAICollections().catchError((e) {
                print("Failed to sync AI data after Google sign-in: $e");
              });

              if (mounted) {
                ErrorHandler.handleSuccess(
                  context: context,
                  message: 'Google sign-in successful! Welcome back.',
                );
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Continue with Google",
              style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignUpScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              "Sign Up",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
