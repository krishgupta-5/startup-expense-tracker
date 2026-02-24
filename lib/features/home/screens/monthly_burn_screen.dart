import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Required for FontFeature
import 'package:google_fonts/google_fonts.dart';

class MonthlyBurnScreen extends StatefulWidget {
  const MonthlyBurnScreen({super.key});

  @override
  State<MonthlyBurnScreen> createState() => _MonthlyBurnScreenState();
}

class _MonthlyBurnScreenState extends State<MonthlyBurnScreen> {
  // State from Code B for the Range Selector
  String _selectedRange = "6M";
  final List<String> _ranges = ["1M", "3M", "6M", "YTD", "ALL"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Code A Background
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header (Code A)
                _buildHeader(context),

                const SizedBox(height: 24),

                // 2. Range Selector (From Code B, styled like Code A)
                _buildRangeSelector(),

                const SizedBox(height: 32),

                // 3. Main Burn Card (Code A)
                _buildMainBurnCard(),

                const SizedBox(height: 32),

                // 4. Burn Trend Chart (Code A)
                _buildBurnTrendSection(),

                const SizedBox(height: 32),

                // 5. Expense Categories (Code A)
                _buildExpenseCategoriesSection(),

                const SizedBox(height: 32),

                // 6. Team Cost Distribution (From Code B, styled like Code A)
                _buildTeamCostSection(),

                const SizedBox(height: 32),

                // 7. Vendor Breakdown (Code A)
                _buildVendorBreakdownSection(),

                const SizedBox(height: 32),

                // 8. Forecast Comparison (Code A)
                _buildForecastComparisonSection(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Header (Code A) ---
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "Burn Analysis",
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Expense Breakdown",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Range Selector (From Code B, Adapted Style) ---
  Widget _buildRangeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _ranges.map((range) {
          final isSelected = _selectedRange == range;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRange = range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  range,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Main Burn Card (Code A) ---
  Widget _buildMainBurnCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F0A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFFFF9F0A).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  "PRIMARY INSIGHT",
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF9F0A),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFF30D158).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  "HIGH IMPACT",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF30D158),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹42.5",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w300,
                  height: 1.0,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "thousand/month",
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Net Burn (after revenue)",
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "₹34,000/month",
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF453A),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Burn Trend (Code A) ---
  Widget _buildBurnTrendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "6-Month Burn Trend",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: SizedBox(
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildFlatBar("Jan", 0.4),
                _buildFlatBar("Feb", 0.5),
                _buildFlatBar("Mar", 0.45),
                _buildFlatBar("Apr", 0.6),
                _buildFlatBar("May", 0.55),
                _buildFlatBar("Jun", 0.8, isActive: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlatBar(String label, double pct, {bool isActive = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: 120 * pct,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : const Color(0xFF1F1F22),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- Expense Categories (Code A) ---
  Widget _buildExpenseCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Expense Categories",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: [
              _buildCategoryRow(
                "Salaries",
                "₹27,625",
                65,
                const Color(0xFF30D158),
              ),
              const SizedBox(height: 24),
              _buildCategoryRow(
                "Servers & Infrastructure",
                "₹8,500",
                20,
                const Color(0xFF3A4B8A),
              ),
              const SizedBox(height: 24),
              _buildCategoryRow(
                "Marketing",
                "₹4,250",
                10,
                const Color(0xFFFF9F0A),
              ),
              const SizedBox(height: 24),
              _buildCategoryRow(
                "Office & Operations",
                "₹2,125",
                5,
                const Color(0xFF00BFA5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Team Cost Distribution (From Code B, Adapted Style) ---
  Widget _buildTeamCostSection() {
    // Data from Code B
    final teams = [
      {"name": "Engineering", "cost": "₹62,000", "pct": 0.65},
      {"name": "Sales", "cost": "₹35,000", "pct": 0.40},
      {"name": "Product", "cost": "₹22,000", "pct": 0.25},
      {"name": "Marketing", "cost": "₹18,000", "pct": 0.20},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Team Cost Distribution",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: teams.map((team) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        team['name'] as String,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        team['cost'] as String,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Stack(
                        children: [
                          Container(
                            height: 4,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F1F22),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: team['pct'] as double,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(
    String label,
    String value,
    int percentage,
    Color color,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100.0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Vendor Breakdown (Code A) ---
  Widget _buildVendorBreakdownSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Top Vendors",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: [
              _buildVendorRow("AWS", "Cloud Services", "₹3,800/month"),
              const SizedBox(height: 16),
              _buildVendorRow("Google Workspace", "Productivity", "₹450/month"),
              const SizedBox(height: 16),
              _buildVendorRow("Slack", "Communication", "₹350/month"),
              const SizedBox(height: 16),
              _buildVendorRow("HubSpot", "Marketing", "₹1,200/month"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVendorRow(String name, String service, String cost) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                name.substring(0, 2).toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  service,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            cost,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // --- Forecast Comparison (Code A) ---
  Widget _buildForecastComparisonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Budget vs Actual",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: [
              _buildComparisonRow(
                "Category",
                "Budget",
                "Actual",
                "Variance",
                true,
              ),
              _buildComparisonRow(
                "Salaries",
                "₹28,000",
                "₹27,625",
                "₹375 under",
                false,
              ),
              _buildComparisonRow(
                "Infrastructure",
                "₹8,000",
                "₹8,500",
                "₹500 over",
                false,
              ),
              _buildComparisonRow(
                "Marketing",
                "₹5,000",
                "₹4,250",
                "₹750 under",
                false,
              ),
              _buildComparisonRow(
                "Operations",
                "₹2,000",
                "₹2,125",
                "₹125 over",
                false,
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Budget",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "₹43,000",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Actual",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "₹42,500",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Variance",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "₹500 under budget",
                    style: GoogleFonts.inter(
                      color: const Color(0xFF30D158),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(
    String category,
    String budget,
    String actual,
    String variance,
    bool isHeader,
  ) {
    bool isOver = variance.contains("over");
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              category,
              style: GoogleFonts.inter(
                color: isHeader ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              budget,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                color: isHeader ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              actual,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                color: isHeader ? Colors.white : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              isHeader
                  ? variance
                  : variance.replaceAll(" under", "").replaceAll(" over", ""),
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                color: isHeader
                    ? Colors.white
                    : isOver
                    ? const Color(0xFFFF453A)
                    : const Color(0xFF30D158),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
