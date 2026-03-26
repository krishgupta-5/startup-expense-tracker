import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/screen/login.dart';
import '../company-setup/screen/company_setup_screen.dart';
import '../navigation/screens/main_navigation_wrapper.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFF09090B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text('Loading...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance
          .idTokenChanges(), // Better for detecting email verification changes
      builder: (context, snapshot) {
        // Show loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        // Handle token refresh errors
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF09090B),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    "Session expired",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Please sign in again",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.currentUser?.reload();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Refresh Session"),
                  ),
                ],
              ),
            ),
          );
        }

        // User is not logged in, show login screen
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // User is logged in, check if they have completed company setup
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }

            // Handle Firestore errors
            if (userSnapshot.hasError) {
              debugPrint('❌ DEBUG: User snapshot error: ${userSnapshot.error}');
              return Scaffold(
                backgroundColor: const Color(0xFF09090B),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Connection Error",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Please check your internet connection",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AuthWrapper(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              );
            }

            debugPrint(
              '🔍 DEBUG: User document exists: ${userSnapshot.hasData}',
            );
            debugPrint(
              '🔍 DEBUG: User document data: ${userSnapshot.data?.data()}',
            );

            // If user document doesn't exist or company not set up, go to company setup
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              debugPrint(
                '🔍 DEBUG: User document does not exist, going to company setup',
              );
              return const CompanySetupScreen();
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            debugPrint('🔍 DEBUG: User data: $userData');
            debugPrint(
              '🔍 DEBUG: Company setup status: ${userData?['companySetup']}',
            );

            if (userData == null || userData['companySetup'] != true) {
              debugPrint(
                '🔍 DEBUG: Company setup not completed, going to company setup screen',
              );
              return const CompanySetupScreen();
            }

            // User has completed setup, go to main navigation
            debugPrint(
              '🔍 DEBUG: Company setup completed, going to main navigation',
            );
            return const MainNavigationWrapper();
          },
        );
      },
    );
  }
}
