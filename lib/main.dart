import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:startup_expense_tracker/features/auth/screen/signup.dart';
import 'package:startup_expense_tracker/features/navigation/screens/main_navigation_wrapper.dart';
import 'package:startup_expense_tracker/firebase_options.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FinancialDashboardApp());
}

class FinancialDashboardApp extends StatelessWidget {
  const FinancialDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadTheme(
      data: ShadThemeData(
        colorScheme: ShadSlateColorScheme.dark().copyWith(
          background: Colors.black,
          card: Colors.black,
          popover: const Color(0xFF1A1A1A),
        ),
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Financial Dashboard',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppTheme.background,
          textTheme: GoogleFonts.interTextTheme(),
          useMaterial3: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        home: StreamBuilder(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data != null) {
              return const MainNavigationWrapper();
            }
            return const SignUpScreen();
          },
        ),
      ),
    );
  }
}
