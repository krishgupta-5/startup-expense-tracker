import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/screen/login.dart';
import '../auth/services/auth_service.dart';
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
                      await AuthService.refreshAuthToken();
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
        return FutureBuilder<bool>(
          future: AuthService.isSessionValid(),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }

            if (sessionSnapshot.data != true) {
              return const LoginScreen();
            }

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
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
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

                // If user document doesn't exist or company not set up, go to company setup
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const CompanySetupScreen();
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;

                if (userData == null || userData['companySetup'] != true) {
                  return const CompanySetupScreen();
                }

                // User has completed setup, go to main navigation
                return const MainNavigationWrapper();
              },
            );
          },
        );
      },
    );
  }
}
