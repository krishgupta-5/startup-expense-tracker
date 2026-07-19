import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup_expense_tracker/theme/app_theme.dart';

class ModernDarkNavBar extends StatelessWidget {
  final Function(int) onTabSelected;
  final int selectedIndex;

  const ModernDarkNavBar({
    super.key,
    required this.onTabSelected,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.navBackground,
        border: Border(top: BorderSide(color: context.borderColor, width: 1.5)),
        boxShadow: context.isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: SafeArea(
        // Using vertical padding allows the widget to size itself naturally
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(
                context,
                0,
                Icons.home_rounded,
                Icons.home_outlined,
                "Home",
              ),
              _buildNavItem(
                context,
                1,
                Icons.groups_rounded,
                Icons.groups_outlined,
                "Team",
              ),
              _buildNavItem(
                context,
                2,
                Icons.receipt_long_rounded,
                Icons.receipt_long_outlined,
                "Expenses",
              ),
              _buildNavItem(
                context,
                3,
                Icons.insights_rounded,
                Icons.insights_outlined,
                "AI",
              ),
              _buildNavItem(
                context,
                4,
                Icons.settings_rounded,
                Icons.settings_outlined,
                "Settings",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    bool isSelected = selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ensures it only takes needed space
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? context.navActiveTab : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? context.textPrimary : context.textSecondary,
                size: 24, // Slightly adjusted for better fit
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              style: GoogleFonts.inter(
                color: isSelected ? context.textPrimary : context.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
