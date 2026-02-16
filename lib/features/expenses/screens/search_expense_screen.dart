import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'expense_details_screen.dart';

class SearchExpenseScreen extends StatefulWidget {
  const SearchExpenseScreen({super.key});

  @override
  State<SearchExpenseScreen> createState() => _SearchExpenseScreenState();
}

class _SearchExpenseScreenState extends State<SearchExpenseScreen> {
  // 1. CONTROLLERS
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // 2. FILTER STATE
  String _selectedYear = "2024";
  String _selectedMonthKey = "all";
  String _selectedCategoryKey = "all";
  String _sortOrder = "newest";
  DateTime _selectedDate = DateTime.now();

  // 3. CONSTANTS & MAPPINGS
  final Map<String, String> _months = {
    'all': 'All',
    'Jan': 'Jan',
    'Feb': 'Feb',
    'Mar': 'Mar',
    'Apr': 'Apr',
    'May': 'May',
    'Jun': 'Jun',
    'Jul': 'Jul',
    'Aug': 'Aug',
    'Sep': 'Sep',
    'Oct': 'Oct',
    'Nov': 'Nov',
    'Dec': 'Dec',
  };

  final Map<String, String> _categories = {
    'all': 'All',
    'Infrastructure': 'Infrastructure',
    'Software': 'Software',
    'Office': 'Office',
    'Marketing': 'Marketing',
    'Meals': 'Meals',
    'Transport': 'Transport',
  };

  // 4. MOCK DATA
  final List<Map<String, dynamic>> _allTransactions = [
    {
      "title": "AWS Server",
      "cat": "Infrastructure",
      "amt": "240.00",
      "date": "Nov 24, 2024",
    },
    {
      "title": "Figma Pro",
      "cat": "Software",
      "amt": "45.00",
      "date": "Nov 23, 2024",
    },
    {
      "title": "WeWork",
      "cat": "Office",
      "amt": "850.00",
      "date": "Nov 22, 2024",
    },
    {
      "title": "Uber Business",
      "cat": "Transport",
      "amt": "24.50",
      "date": "Nov 21, 2024",
    },
    {
      "title": "Slack",
      "cat": "Software",
      "amt": "12.00",
      "date": "Oct 20, 2024",
    },
    {
      "title": "Google Ads",
      "cat": "Marketing",
      "amt": "500.00",
      "date": "Oct 19, 2024",
    },
    {
      "title": "Client Dinner",
      "cat": "Meals",
      "amt": "120.00",
      "date": "Sep 18, 2024",
    },
    {
      "title": "Apple Store",
      "cat": "Infrastructure",
      "amt": "2200.00",
      "date": "Nov 15, 2023",
    },
  ];

  // 5. HELPER: Parse "Nov 24, 2024" to DateTime
  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.replaceAll(',', '').split(' ');
      if (parts.length != 3) return null;

      final monthStr = parts[0];
      final day = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final monthMap = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12,
      };

      final month = monthMap[monthStr] ?? 1;
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  // 6. FILTER LOGIC
  List<Map<String, dynamic>> get _filteredTransactions {
    // A. FILTER
    final filtered = _allTransactions.where((tx) {
      final txDate = _parseDate(tx["date"]);
      if (txDate == null) return false;

      // 1. Search Query
      final matchesQuery = tx["title"].toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );

      // 2. Category Filter (Always applies)
      bool matchesCategory = true;
      if (_selectedCategoryKey != 'all') {
        matchesCategory = tx["cat"] == _categories[_selectedCategoryKey];
      }

      // 3. Date Logic (Month/Year only)
      final matchesYear = txDate.year.toString() == _selectedYear;

      bool matchesMonth = true;
      if (_selectedMonthKey != 'all') {
        final dataMonth = tx["date"].toString().split(' ')[0];
        matchesMonth =
            dataMonth.toLowerCase() == _selectedMonthKey.toLowerCase();
      }
      final matchesDateLogic = matchesYear && matchesMonth;

      return matchesQuery && matchesCategory && matchesDateLogic;
    }).toList();

    // B. SORT
    filtered.sort((a, b) {
      final dateA = _parseDate(a["date"]) ?? DateTime.now();
      final dateB = _parseDate(b["date"]) ?? DateTime.now();
      if (_sortOrder == 'newest') {
        return dateB.compareTo(dateA);
      } else {
        return dateA.compareTo(dateB);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              // --- HEADER & SEARCH ---
              _buildHeader(),

              const SizedBox(height: 24),

              // --- FILTERS ---

              // 1. TOP ROW: Year/Date Controls + Sort
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    // Year Dropdown
                    _buildDropdownTrigger(
                      label: "Year: $_selectedYear",
                      onTap: () => _showYearSelector(),
                    ),
                    const SizedBox(width: 8),

                    // Date Picker Button (ShadCN Calendar)
                    GestureDetector(
                      onTap: () => _showDatePicker(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Sort Dropdown (Always visible)
                    _buildDropdownTrigger(
                      label: _sortOrder == 'newest' ? "Newest" : "Oldest",
                      onTap: () => _showSortSelector(),
                      icon: Icons.sort,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. MONTH ROW
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _months.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final key = _months.keys.elementAt(index);
                    final label = _months[key]!;
                    final isSelected =
                        _selectedMonthKey.toLowerCase() == key.toLowerCase();

                    return GestureDetector(
                      onTap: () => setState(() => _selectedMonthKey = key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF30D158).withValues(alpha: 0.15)
                              : const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF30D158)
                                : Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? const Color(0xFF30D158)
                                : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 3. CATEGORY ROW
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final key = _categories.keys.elementAt(index);
                    final label = _categories[key]!;
                    final isSelected = _selectedCategoryKey == key;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategoryKey = key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.black : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
              const Divider(color: Color(0xFF1F1F22), height: 1),

              // --- RESULTS LIST ---
              Expanded(
                child: _filteredTransactions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = _filteredTransactions[index];
                          return _buildTransactionRow(tx);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Filter Expenses",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
              cursorColor: const Color(0xFF30D158),
              decoration: InputDecoration(
                hintText: "Search title...",
                hintStyle: GoogleFonts.inter(color: Colors.white24),
                border: InputBorder.none,
                icon: const Icon(Icons.search, color: Colors.white38, size: 20),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTrigger({
    required String label,
    required VoidCallback onTap,
    IconData icon = Icons.keyboard_arrow_down,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(Map<String, dynamic> tx) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ExpenseDetailsScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: const Icon(Icons.receipt, color: Colors.white38, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx["title"],
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${tx["cat"]} • ${tx["date"]}",
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
              "-\$${tx["amt"]}",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.filter_list_off, color: Colors.white12, size: 48),
          const SizedBox(height: 16),
          Text(
            "No expenses found",
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                      "Select Date",
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
                  selected: _selectedDate,
                  fromMonth: DateTime(_selectedDate.year - 1),
                  toMonth: DateTime(_selectedDate.year + 1, 12),
                  onChanged: (DateTime? date) {
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                        // Update year and month based on selected date
                        _selectedYear = date.year.toString();
                        _selectedMonthKey = _months.keys.elementAt(
                          date.month - 1,
                        );
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showYearSelector() {
    final years = ['2025', '2024', '2023', '2022'];
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                      "Select Year",
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
                ...years.map(
                  (year) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedYear = year);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedYear == year
                              ? const Color(0xFF30D158).withValues(alpha: 0.15)
                              : const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedYear == year
                                ? const Color(0xFF30D158)
                                : Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Text(
                          year,
                          style: GoogleFonts.inter(
                            color: _selectedYear == year
                                ? const Color(0xFF30D158)
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  void _showSortSelector() {
    final sortOptions = ['Newest', 'Oldest'];
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                      "Sort Order",
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
                ...sortOptions.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _sortOrder = option.toLowerCase());
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: _sortOrder == option.toLowerCase()
                              ? const Color(0xFF30D158).withValues(alpha: 0.15)
                              : const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _sortOrder == option.toLowerCase()
                                ? const Color(0xFF30D158)
                                : Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Text(
                          option,
                          style: GoogleFonts.inter(
                            color: _sortOrder == option.toLowerCase()
                                ? const Color(0xFF30D158)
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
}
