import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:startup_expense_tracker/widgets/custom_bottom_nav.dart';
import 'package:startup_expense_tracker/features/home/screens/home_screen.dart';
import 'package:startup_expense_tracker/features/team/screens/team_screen.dart';
import 'package:startup_expense_tracker/features/expenses/screens/expenses_screen.dart';
import 'package:startup_expense_tracker/features/ai/screens/ai_screen.dart';
import 'package:startup_expense_tracker/features/settings/screens/settings_screen.dart';

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(onNavigateToTab: null), // Will be updated below
    const TeamScreen(),
    const ExpensesScreen(),
    const AiScreen(),
    const SettingsScreen(),
  ];

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: _buildCurrentScreen(),
      ),
      bottomNavigationBar: ModernDarkNavBar(
        onTabSelected: _onTabSelected,
        selectedIndex: _selectedIndex,
      ),
    );
  }

  Widget _buildCurrentScreen() {
    // Update the HomeScreen with the navigation callback
    if (_selectedIndex == 0) {
      return HomeScreen(onNavigateToTab: _onTabSelected);
    }
    return _screens[_selectedIndex];
  }
}
