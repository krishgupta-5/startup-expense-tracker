import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Required for FontFeature
import 'package:google_fonts/google_fonts.dart';
import '../../../services/financial_data_service.dart';

class MonthlyBurnScreen extends StatefulWidget {
  const MonthlyBurnScreen({super.key});

  @override
  State<MonthlyBurnScreen> createState() => _MonthlyBurnScreenState();
}

class _MonthlyBurnScreenState extends State<MonthlyBurnScreen> {
  // State from Code B for the Range Selector
  String _selectedRange = "6M";
  final List<String> _ranges = ["1M", "3M", "6M", "YTD", "ALL"];

  // Real data state
  Map<String, dynamic>? _financialData;
  Map<String, dynamic>? _teamCostData;
  List<Map<String, dynamic>>? _rawTeamsData;
  Map<String, double>? _actualSpendingPerTeam;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final financialData = await FinancialDataService.getMonthlyBurnData();
      final teamCostData = await FinancialDataService.getTeamCostDistribution();
      final rawTeamsData = await FinancialDataService.getRawTeamsData();
      final actualSpendingPerTeam =
          await FinancialDataService.getActualSpendingPerTeam();

      setState(() {
        _financialData = financialData;
        _teamCostData = teamCostData;
        _rawTeamsData = rawTeamsData;
        _actualSpendingPerTeam = actualSpendingPerTeam;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

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

  // --- Main Burn Card (Real Data) ---
  Widget _buildMainBurnCard() {
    if (_isLoading) {
      return _buildLoadingCard();
    }

    if (_error != null) {
      return _buildErrorCard();
    }

    final grossBurn = _financialData?['grossBurn'] ?? 42500;
    final netBurn = _financialData?['netBurn'] ?? 34000;

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
                "₹${grossBurn.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  height: 1.0,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "/month",
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
                  "₹${netBurn.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}",
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

  // --- Loading and Error States ---
  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF453A), size: 48),
          const SizedBox(height: 16),
          Text(
            "Failed to load financial data",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? "Unknown error",
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadFinancialData,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF30D158).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF30D158).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                "Retry",
                style: GoogleFonts.inter(
                  color: const Color(0xFF30D158),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Burn Trend (Real Data) ---
  Widget _buildBurnTrendSection() {
    if (_isLoading) {
      return _buildLoadingSection("6-Month Burn Trend");
    }

    if (_error != null) {
      return _buildErrorSection("6-Month Burn Trend");
    }

    final trendData =
        _financialData?['trendData'] as List<Map<String, dynamic>>? ?? [];

    // If no trend data, provide fallback data for demonstration
    final displayData = trendData.isEmpty ? _getFallbackTrendData() : trendData;

    // Calculate maxAmount once before building the chart
    final maxAmount = displayData
        .map((d) => d['amount'] as double)
        .reduce((a, b) => a > b ? a : b);

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
              children: displayData.map((data) {
                final percentage = maxAmount > 0
                    ? (data['amount'] as double) / maxAmount
                    : 0.0;
                return _buildFlatBar(
                  data['month'] as String,
                  percentage,
                  isActive: data['isCurrentMonth'] as bool,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // --- Helper Methods for Loading/Error States ---
  Widget _buildLoadingSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
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
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
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
          child: Center(
            child: Text(
              "Failed to load data",
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
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

  // --- Expense Categories (Real Data) ---
  Widget _buildExpenseCategoriesSection() {
    if (_isLoading) {
      return _buildLoadingSection("Expense Categories");
    }

    if (_error != null) {
      return _buildErrorSection("Expense Categories");
    }

    final categoryBreakdown =
        _financialData?['categoryBreakdown'] as Map<String, double>? ?? {};
    final totalExpenses = _financialData?['totalExpenses'] as double? ?? 0;

    // Default categories with colors if no data
    final defaultCategories = {
      'Salaries': {'amount': 27625.0, 'color': const Color(0xFF30D158)},
      'Servers & Infrastructure': {
        'amount': 8500.0,
        'color': const Color(0xFF3A4B8A),
      },
      'Marketing': {'amount': 4250.0, 'color': const Color(0xFFFF9F0A)},
      'Office & Operations': {
        'amount': 2125.0,
        'color': const Color(0xFF00BFA5),
      },
    };

    final categories = categoryBreakdown.isEmpty
        ? defaultCategories
        : categoryBreakdown.map(
            (key, value) => MapEntry(key, {
              'amount': value,
              'color': _getCategoryColor(key),
            }),
          );

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
            children: categories.entries.map((entry) {
              final amount = entry.value['amount'] as double;
              final color = entry.value['color'] as Color;
              final percentage = totalExpenses > 0
                  ? (amount / totalExpenses * 100).round()
                  : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildCategoryRow(
                  _capitalizeFirstLetter(entry.key),
                  "₹${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}",
                  percentage,
                  color,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'salaries':
      case 'salary':
        return const Color(0xFF30D158);
      case 'servers':
      case 'infrastructure':
      case 'servers & infrastructure':
        return const Color(0xFF3A4B8A);
      case 'marketing':
        return const Color(0xFFFF9F0A);
      case 'office':
      case 'operations':
      case 'office & operations':
        return const Color(0xFF00BFA5);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  // --- Team Cost Distribution (Real Data) ---
  Widget _buildTeamCostSection() {
    if (_isLoading) {
      return _buildLoadingSection("Team Cost Distribution");
    }

    if (_error != null) {
      return _buildErrorSection("Team Cost Distribution");
    }

    final teamCosts =
        _teamCostData?['teamCosts'] as List<Map<String, dynamic>>? ?? [];

    // Check if there's actual team data
    if (teamCosts.isEmpty) {
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
              children: [
                const Icon(
                  Icons.groups_outlined,
                  color: Colors.white24,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  "No team data available",
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create teams and add members to see cost distribution",
                  style: GoogleFonts.inter(
                    color: Colors.white24,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

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
            children: teamCosts.map((team) {
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
                            widthFactor: (team['pct'] as double) > 0
                                ? (team['pct'] as double)
                                : 0.05,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: (team['pct'] as double) > 0
                                    ? Colors.white
                                    : Colors.white24,
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
        // Category name - takes more space
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.left,
          ),
        ),
        const SizedBox(width: 16),
        // Amount - fixed width for alignment
        SizedBox(
          width: 80,
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 16),
        // Progress bar - takes remaining space
        Expanded(
          flex: 3,
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

  // Helper method to capitalize first letter
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
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
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Stack(
            children: [
              // Original vendor content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildVendorRow("AWS", "Cloud Services", "₹3,800/month"),
                    const SizedBox(height: 16),
                    _buildVendorRow(
                      "Google Workspace",
                      "Productivity",
                      "₹450/month",
                    ),
                    const SizedBox(height: 16),
                    _buildVendorRow("Slack", "Communication", "₹350/month"),
                    const SizedBox(height: 16),
                    _buildVendorRow("HubSpot", "Marketing", "₹1,200/month"),
                  ],
                ),
              ),
              // Blurred overlay with "Coming Soon" text
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0A84FF,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: const Color(
                              0xFF0A84FF,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          "COMING SOON",
                          style: GoogleFonts.inter(
                            color: const Color(0xFF0A84FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Vendor analytics will be available",
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "in the next update",
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

  // Helper method to format currency properly
  String _formatCurrency(double amount) {
    // Convert to integer to remove decimal places, then format with commas
    final intAmount = amount.round();
    return '₹${intAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
  }

  // --- Forecast Comparison (Real Data) ---
  Widget _buildForecastComparisonSection() {
    if (_isLoading) {
      return _buildLoadingSection("Budget vs Actual");
    }

    if (_error != null) {
      return _buildErrorSection("Budget vs Actual");
    }

    final rawTeamsData = _rawTeamsData ?? [];

    if (rawTeamsData.isEmpty) {
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
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white24,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  "No team budget data available",
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create teams and set budgets to see comparison",
                  style: GoogleFonts.inter(
                    color: Colors.white24,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Calculate totals
    double totalBudget = 0;
    double totalActual = 0;
    List<Map<String, dynamic>> comparisonData = [];

    for (var team in rawTeamsData) {
      final teamName = team['teamName'] as String? ?? 'Unknown Team';

      // Better parsing for monthlyBudget - handle various formats
      String budgetStr = (team['monthlyBudget']?.toString() ?? '0');
      // Remove any non-digit characters except decimal point
      budgetStr = budgetStr.replaceAll(RegExp(r'[^\d.]'), '');
      final budget = double.tryParse(budgetStr) ?? 0.0;

      final actual = _actualSpendingPerTeam?[teamName] ?? 0.0;
      final variance = budget - actual;

      totalBudget += budget;
      totalActual += actual;

      comparisonData.add({
        'team': teamName,
        'budget': budget,
        'actual': actual,
        'variance': variance,
        'isOver': variance < 0,
      });
    }

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
              _buildComparisonRow("Team", "Budget", "Actual", "Variance", true),
              ...comparisonData
                  .map(
                    (data) => _buildComparisonRow(
                      data['team'] as String,
                      _formatCurrency(data['budget'] as double),
                      _formatCurrency(data['actual'] as double),
                      data['isOver'] as bool
                          ? "${_formatCurrency((data['variance'] as double).abs())} over"
                          : "${_formatCurrency((data['variance'] as double).abs())} under",
                      false,
                    ),
                  )
                  ,
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
                    _formatCurrency(totalBudget),
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
                    _formatCurrency(totalActual),
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
                    totalBudget >= totalActual
                        ? "${_formatCurrency(totalBudget - totalActual)} under budget"
                        : "${_formatCurrency(totalActual - totalBudget)} over budget",
                    style: GoogleFonts.inter(
                      color: totalBudget >= totalActual
                          ? const Color(0xFF30D158)
                          : const Color(0xFFFF453A),
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
            flex: 4,
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
            flex: 4,
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
            flex: 4,
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

  // --- Fallback Data Method ---
  List<Map<String, dynamic>> _getFallbackTrendData() {
    final now = DateTime.now();
    final fallbackData = <Map<String, dynamic>>[];

    // Create realistic burn data with variations
    final baseAmount = 35000.0;
    final variations = [
      0.9,
      1.1,
      0.95,
      1.05,
      0.85,
      1.0,
    ]; // Different multipliers for each month

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final amount = baseAmount * variations[i];
      fallbackData.add({
        'month': _getMonthAbbreviation(month.month),
        'amount': amount,
        'isCurrentMonth': i == 0,
      });
    }

    return fallbackData;
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
