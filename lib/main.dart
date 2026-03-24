import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:startup_expense_tracker/features/auth/auth_wrapper.dart';
import 'package:startup_expense_tracker/firebase_options.dart';
import 'theme/app_theme.dart';

void main() async {
  await dotenv.load(fileName: ".env.local");
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
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark(),
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
        home: const AuthWrapper(),
      ),
    );
  }
}
