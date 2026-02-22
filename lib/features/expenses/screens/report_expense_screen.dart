import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ReportExpenseScreen extends StatefulWidget {
  const ReportExpenseScreen({super.key});

  @override
  State<ReportExpenseScreen> createState() => _ReportExpenseScreenState();
}

class _ReportExpenseScreenState extends State<ReportExpenseScreen> {
  // 1. DEFAULT TO WEEKLY (LAST 7 DAYS)
  String _selectedPeriod = "weekly";
  String _selectedCategory = "all";

  DateTime? _customStartDate;
  DateTime? _customEndDate;

  String _formatCurrency(double amount) {
    return "₹${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String _formatShortDate(DateTime date) {
    final List<String> months = [
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
    return "${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}";
  }

  String _formatMonthYear(DateTime date) {
    final List<String> months = [
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
    return "${months[date.month - 1]} '${date.year.toString().substring(2)}";
  }

  void _showShadCalendar({required bool isStart}) {
    DateTime initialDate = isStart
        ? (_customStartDate ?? DateTime.now())
        : (_customEndDate ?? _customStartDate ?? DateTime.now());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        DateTime tempSelectedDate = initialDate;

        return Dialog(
          backgroundColor: const Color(0xFF09090B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isStart ? "Select Start Date" : "Select End Date",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white38),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ShadCalendar(
                  selected: tempSelectedDate,
                  fromMonth: DateTime(DateTime.now().year - 5),
                  toMonth: DateTime(DateTime.now().year + 5, 12),
                  onChanged: (DateTime? date) {
                    if (date != null) {
                      tempSelectedDate = date;
                    }
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (isStart) {
                          _customStartDate = tempSelectedDate;
                          if (_customEndDate != null &&
                              _customEndDate!.isBefore(_customStartDate!)) {
                            _customEndDate = null;
                          }
                        } else {
                          _customEndDate = tempSelectedDate;
                        }
                        if (_customStartDate != null &&
                            _customEndDate != null) {
                          _selectedPeriod = "custom";
                        }
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Done",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('expenses')
                      .where('uid', isEqualTo: currentUser?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white38),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Failed to load reports.",
                          style: GoogleFonts.inter(color: Colors.redAccent),
                        ),
                      );
                    }

                    DateTime now = DateTime.now();
                    DateTime startDate;
                    DateTime endDate = now;

                    if (_selectedPeriod == "weekly") {
                      startDate = now.subtract(const Duration(days: 6));
                    } else if (_selectedPeriod == "monthly") {
                      startDate = now.subtract(const Duration(days: 29));
                    } else if (_selectedPeriod == "quarterly") {
                      startDate = now.subtract(const Duration(days: 89));
                    } else if (_selectedPeriod == "yearly") {
                      startDate = now.subtract(const Duration(days: 364));
                    } else if (_selectedPeriod == "custom" &&
                        _customStartDate != null &&
                        _customEndDate != null) {
                      startDate = _customStartDate!;
                      endDate = _customEndDate!;
                    } else {
                      startDate = now.subtract(const Duration(days: 6));
                    }

                    startDate = DateTime(
                      startDate.year,
                      startDate.month,
                      startDate.day,
                    );
                    endDate = DateTime(
                      endDate.year,
                      endDate.month,
                      endDate.day,
                      23,
                      59,
                      59,
                    );

                    int daysInPeriod = endDate.difference(startDate).inDays;
                    if (daysInPeriod <= 0) daysInPeriod = 1;

                    double totalExpenses = 0.0;
                    Map<String, double> categoryBreakdown = {};

                    bool isDailyChart = daysInPeriod <= 31;
                    Map<String, double> chartData = {};
                    List<String> chartLabels = [];

                    // --- FORCE ONLY LAST 7 DAYS IN DAILY CHART ---
                    if (isDailyChart) {
                      int displayDays = min(daysInPeriod, 6); // 0 to 6 = 7 days
                      DateTime chartStartDate = endDate.subtract(
                        Duration(days: displayDays),
                      );

                      for (int i = 0; i <= displayDays; i++) {
                        DateTime d = chartStartDate.add(Duration(days: i));
                        String key =
                            "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
                        chartData[key] = 0.0;
                        chartLabels.add(_formatShortDate(d));
                      }
                    } else {
                      DateTime tempDate = DateTime(
                        startDate.year,
                        startDate.month,
                        1,
                      );
                      while (tempDate.isBefore(endDate) ||
                          tempDate.isAtSameMomentAs(
                            DateTime(endDate.year, endDate.month, 1),
                          )) {
                        String key =
                            "${tempDate.year}-${tempDate.month.toString().padLeft(2, '0')}";
                        chartData[key] = 0.0;
                        chartLabels.add(_formatMonthYear(tempDate));
                        tempDate = DateTime(
                          tempDate.year,
                          tempDate.month + 1,
                          1,
                        );
                      }
                    }

                    final docs = snapshot.data?.docs ?? [];
                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final Timestamp? ts = data['Date'] as Timestamp?;
                      final DateTime docDate = ts?.toDate() ?? now;
                      final String category =
                          (data['Category']?.toString() ?? 'other')
                              .toLowerCase();
                      final double amount = data['Amount'] is int
                          ? (data['Amount'] as int).toDouble()
                          : (data['Amount'] as double? ?? 0.0);

                      if (docDate.isBefore(startDate) ||
                          docDate.isAfter(endDate))
                        continue;
                      if (_selectedCategory != "all" &&
                          category != _selectedCategory)
                        continue;

                      totalExpenses += amount;
                      categoryBreakdown[category] =
                          (categoryBreakdown[category] ?? 0.0) + amount;

                      if (isDailyChart) {
                        String key =
                            "${docDate.year}-${docDate.month.toString().padLeft(2, '0')}-${docDate.day.toString().padLeft(2, '0')}";
                        if (chartData.containsKey(key)) {
                          chartData[key] = chartData[key]! + amount;
                        }
                      } else {
                        String key =
                            "${docDate.year}-${docDate.month.toString().padLeft(2, '0')}";
                        if (chartData.containsKey(key)) {
                          chartData[key] = chartData[key]! + amount;
                        }
                      }
                    }

                    double averageDaily =
                        totalExpenses / (daysInPeriod == 0 ? 1 : daysInPeriod);

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32),
                          _buildPeriodSelector(),
                          const SizedBox(height: 24),
                          _buildDateRangePicker(),
                          const SizedBox(height: 24),
                          _buildCategoryFilter(),
                          const SizedBox(height: 32),
                          _buildSummaryCards(totalExpenses, averageDaily),
                          const SizedBox(height: 32),

                          // Custom Chart (Never Scrolls horizontally now)
                          _buildChartSection(
                            chartData.values.toList(),
                            chartLabels,
                            isDailyChart,
                          ),

                          const SizedBox(height: 32),
                          _buildDetailedBreakdown(
                            categoryBreakdown,
                            totalExpenses,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          Text(
            "Expense Report",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          GestureDetector(
            onTap: () => _exportReport(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: const Icon(Icons.download, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Report Period",
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPeriodChip("Weekly", "weekly"),
              const SizedBox(width: 12),
              _buildPeriodChip("Monthly", "monthly"),
              const SizedBox(width: 12),
              _buildPeriodChip("Quarterly", "quarterly"),
              const SizedBox(width: 12),
              _buildPeriodChip("Yearly", "yearly"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    bool isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedPeriod = value;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A84FF) : const Color(0xFF141416),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Custom Date Range",
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showShadCalendar(isStart: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _customStartDate != null
                            ? _formatDate(_customStartDate!)
                            : "Start Date",
                        style: GoogleFonts.inter(
                          color: _customStartDate != null
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white38,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _showShadCalendar(isStart: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _customEndDate != null
                            ? _formatDate(_customEndDate!)
                            : "End Date",
                        style: GoogleFonts.inter(
                          color: _customEndDate != null
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white38,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      "All",
      "Salary",
      "Infrastructure",
      "Software",
      "Office",
      "Marketing",
      "Meals",
      "Transport",
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Category Filter",
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((category) {
              bool isSelected = _selectedCategory == category.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(
                    () => _selectedCategory = category.toLowerCase(),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0A84FF)
                          : const Color(0xFF141416),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      category,
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(double total, double averageDaily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Summary",
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                "Total Expenses",
                _formatCurrency(total),
                Icons.account_balance_wallet,
                const Color(0xFFFF453A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                "Average Daily",
                _formatCurrency(averageDaily),
                Icons.show_chart,
                const Color(0xFF30D158),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- REBUILT CHART SO IT NEVER SCROLLS HORIZONTALLY ---
  Widget _buildChartSection(
    List<double> data,
    List<String> labels,
    bool isDailyChart,
  ) {
    if (data.isEmpty) return const SizedBox.shrink();

    double maxVal = data.reduce(max);
    if (maxVal == 0) maxVal = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDailyChart ? "Expense Trend (Last 7 Days)" : "Expense Trend",
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 240,
          padding: const EdgeInsets.only(
            top: 24,
            bottom: 16,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          // Uses Row instead of ListView so it evenly spaces the bars
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(data.length, (index) {
              double heightPercentage = data[index] / maxVal;
              if (data[index] == 0)
                heightPercentage = 0.02; // Tiny nub so empty days show up

              // Splits label into "Day" and "Month" so it wraps nicely
              List<String> labelParts = labels[index].split(' ');

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (data[index] > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        data[index] >= 1000
                            ? "₹${(data[index] / 1000).toStringAsFixed(1)}k"
                            : "₹${data[index].toStringAsFixed(0)}",
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    width: 20, // Clean fixed width
                    height: 120 * heightPercentage,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0A84FF),
                          const Color(0xFF0A84FF).withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Label formatting logic to prevent squishing
                  Text(
                    labelParts[0],
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (labelParts.length > 1)
                    Text(
                      labelParts[1],
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 9,
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedBreakdown(Map<String, double> breakdown, double total) {
    if (breakdown.isEmpty) return const SizedBox.shrink();

    var sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Category Breakdown",
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: sortedEntries.asMap().entries.map((entry) {
              int index = entry.key;
              String categoryName = entry.value.key;
              double amount = entry.value.value;
              double percentage = total > 0 ? (amount / total) : 0;

              String displayCategory = categoryName.isEmpty
                  ? "Other"
                  : categoryName[0].toUpperCase() + categoryName.substring(1);

              return Column(
                children: [
                  _buildBreakdownRow(
                    displayCategory,
                    _formatCurrency(amount),
                    percentage,
                  ),
                  if (index != sortedEntries.length - 1) _buildDivider(),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String category, String amount, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            category,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Text(
                amount,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 55,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${(percentage * 100).toStringAsFixed(1)}%",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0A84FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.white.withValues(alpha: 0.04), height: 1);
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF141416),
        content: Text(
          "Export feature coming soon",
          style: GoogleFonts.inter(color: Colors.white),
        ),
      ),
    );
  }
}
