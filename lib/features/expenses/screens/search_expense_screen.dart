import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:startup_expense_tracker/services/user_country_service.dart';
import '../../../utils/data_helpers.dart';
import '../../../services/currency_formatter.dart';
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
  String _userCountryCode = '+1'; // Default to USD
  bool _isLoadingCountry = true;

  // 2. FILTER STATE
  late String _selectedYear;
  String _selectedMonthKey = "all";
  String _selectedCategoryKey = "all";
  String _sortOrder = "newest";

  // If this is set, it overrides the Month/Year filter to search for an exact day
  DateTime? _exactDate;

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
    'marketing': 'Marketing',
    'infrastructure': 'Infrastructure',
    'office': 'Office',
    'software': 'Software',
    'hardware': 'Hardware',
    'transport': 'Transport',
    'design': 'Design',
    'travel': 'Travel',
    'meals': 'Meals',
    'contractors': 'Contractors',
    'legal': 'Legal',
    'others': 'Others',
  };

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year.toString();
    _loadUserCountryCode();
  }

  Future<void> _loadUserCountryCode() async {
    final countryCode = await UserCountryService.getUserCountryCode();
    if (mounted) {
      setState(() {
        _userCountryCode = countryCode;
        _isLoadingCountry = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 4. PAGINATION STATE
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;
  bool _hasMore = true;

  Query _buildExpensesQuery() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    Query query = FirebaseFirestore.instance
        .collection('expenses')
        .where('uid', isEqualTo: user.uid)
        // Use _sortOrder to control ascending/descending direction
        .orderBy('Date', descending: _sortOrder == 'newest')
        .limit(_pageSize);

    // Apply date filters
    if (_exactDate != null) {
      final startOfDay = DateTime(
        _exactDate!.year,
        _exactDate!.month,
        _exactDate!.day,
      );
      final endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
      query = query
          .where('Date', isGreaterThanOrEqualTo: startOfDay)
          .where('Date', isLessThan: endOfDay);
    } else if (_selectedMonthKey != 'all') {
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
      final month = monthMap[_selectedMonthKey];
      if (month != null) {
        final year = int.tryParse(_selectedYear) ?? DateTime.now().year;
        final startOfMonth = DateTime(year, month);
        final endOfMonth = DateTime(
          year,
          month + 1,
          0,
        ).subtract(const Duration(milliseconds: 1));
        query = query
            .where('Date', isGreaterThanOrEqualTo: startOfMonth)
            .where('Date', isLessThan: endOfMonth);
      }
    } else {
      // When "all" months is selected, still apply year filter
      final year = int.tryParse(_selectedYear) ?? DateTime.now().year;
      final startOfYear = DateTime(year, 1, 1);
      final endOfYear = DateTime(
        year + 1,
        1,
        1,
      ).subtract(const Duration(milliseconds: 1));
      query = query
          .where('Date', isGreaterThanOrEqualTo: startOfYear)
          .where('Date', isLessThan: endOfYear);
    }

    // Apply category filter
    if (_selectedCategoryKey != 'all') {
      query = query.where('Category', isEqualTo: _selectedCategoryKey);
    }

    // Title filter is applied client-side for case-insensitive matching
    // (Firestore range queries are case-sensitive, so we filter after fetch)

    // Apply pagination
    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    return query;
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

                    // Date Picker Button
                    GestureDetector(
                      onTap: () => _showDatePicker(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _exactDate != null
                              ? Colors.white
                              : Colors.white.withValues(
                                  alpha: 0.05,
                                ), // White Glass Style
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _exactDate != null
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Icon(
                          Icons.calendar_month,
                          color: _exactDate != null
                              ? Colors.black
                              : Colors.white54,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Sort Dropdown
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
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _months.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final key = _months.keys.elementAt(index);
                    final label = _months[key]!;
                    final isSelected =
                        _selectedMonthKey.toLowerCase() == key.toLowerCase() &&
                        _exactDate == null;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMonthKey = key;
                          _exactDate =
                              null; // Clear exact date if user clicks a month
                          _lastDocument =
                              null; // Reset pagination when filter changes
                          _hasMore = true;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
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
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final key = _categories.keys.elementAt(index);
                    final label = _categories[key]!;
                    final isSelected = _selectedCategoryKey == key;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategoryKey = key;
                          _lastDocument = null; // Reset pagination
                          _hasMore = true;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
              const Divider(color: Color(0xFF1F1F22), height: 1),

              // --- RESULTS LIST (FIREBASE STREAM) ---
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: _buildFirebaseResults(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFirebaseResults() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildEmptyState('User not logged in');

    final query = _buildExpensesQuery();

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyState('Failed to load data');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(_getNotFoundMessage());
        }

        // Client-side case-insensitive title filter
        final allDocs = snapshot.data!.docs;
        final filteredDocs = _searchQuery.isEmpty
            ? allDocs
            : allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final title = (data['Title'] ?? '').toString().toLowerCase();
                return title.contains(_searchQuery.toLowerCase());
              }).toList();

        if (filteredDocs.isEmpty) {
          return _buildEmptyState(_getNotFoundMessage());
        }

        // Update pagination state
        if (allDocs.length < _pageSize) {
          _hasMore = false;
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            return _buildTransactionRow(filteredDocs[index]);
          },
        );
      },
    );
  }

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
                  letterSpacing: -0.5, // Premium tracking
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05), // White Glass
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
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
              onTapOutside: (event) => FocusScope.of(context).unfocus(),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: "Search title...",
                hintStyle: GoogleFonts.inter(color: Colors.white24),
                border: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white38,
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                        child: const Icon(
                          Icons.cancel,
                          color: Colors.white38,
                          size: 16,
                        ),
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _lastDocument = null; // Reset pagination when search changes
                  _hasMore = true;
                });
              },
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
          color: Colors.white.withValues(alpha: 0.05), // White Glass
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

  Widget _buildTransactionRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final id = doc.id;

    final title = data['Title'] ?? 'Unnamed Expense';
    final amount = DataHelpers.safeParseDouble(data['Amount']);

    final rawCategory = data['Category']?.toString() ?? 'General';
    final category = rawCategory.isNotEmpty
        ? '${rawCategory[0].toUpperCase()}${rawCategory.substring(1)}'
        : 'General';

    String dateStr = '';
    if (data['Date'] is Timestamp) {
      final date = (data['Date'] as Timestamp).toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      dateStr = "$day/$month/${date.year}";
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ExpenseDetailsScreen(expenseId: id, expenseData: data),
          ),
        ).then((_) {
          // Trigger rebuild to refresh data if it was edited
          setState(() {
            _lastDocument = null;
          });
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.05,
                ), // White Glass Style
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: Colors.white54,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$category • $dateStr",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // FIXED: FITTED BOX FOR LARGE NUMBERS
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                "-${_isLoadingCountry ? '₹' : CurrencyFormatter.getCurrencySymbol(_userCountryCode)}${amount.toStringAsFixed(2)}",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNotFoundMessage() {
    // Check if any filters are active
    bool hasSearchFilter = _searchQuery.isNotEmpty;
    bool hasDateFilter = _exactDate != null || _selectedMonthKey != 'all';
    bool hasCategoryFilter = _selectedCategoryKey != 'all';

    if (hasSearchFilter && hasDateFilter && hasCategoryFilter) {
      return "No expenses found matching \"$_searchQuery\" for ${_selectedMonthKey == 'all' ? _selectedYear : _selectedMonthKey} in ${_getCategoryDisplayName()}";
    } else if (hasSearchFilter && hasDateFilter) {
      return "No expenses found matching \"$_searchQuery\" for ${_selectedMonthKey == 'all' ? _selectedYear : _selectedMonthKey}";
    } else if (hasSearchFilter && hasCategoryFilter) {
      return "No expenses found matching \"$_searchQuery\" in ${_getCategoryDisplayName()}";
    } else if (hasDateFilter && hasCategoryFilter) {
      return "No expenses found for ${_selectedMonthKey == 'all' ? _selectedYear : _selectedMonthKey} in ${_getCategoryDisplayName()}";
    } else if (hasSearchFilter) {
      return "No expenses found matching \"$_searchQuery\"";
    } else if (hasDateFilter) {
      return "No expenses found for ${_selectedMonthKey == 'all' ? _selectedYear : _selectedMonthKey}";
    } else if (hasCategoryFilter) {
      return "No expenses found in ${_getCategoryDisplayName()}";
    } else {
      return "No expenses found";
    }
  }

  String _getCategoryDisplayName() {
    return _categories[_selectedCategoryKey] ?? 'Unknown';
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Text(
          message,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
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
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
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
                const SizedBox(height: 16),
                ShadCalendar(
                  selected: _exactDate ?? DateTime.now(),
                  fromMonth: DateTime(int.parse(_selectedYear) - 2, 1),
                  toMonth: DateTime(int.parse(_selectedYear) + 2, 12),
                  onChanged: (DateTime? date) {
                    if (date != null) {
                      setState(() {
                        _exactDate = date;
                        _selectedYear = date.year.toString();
                        _selectedMonthKey = _months.keys.elementAt(
                          date.month,
                        ); // 1 = Jan, etc.
                        _lastDocument = null;
                        _hasMore = true;
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
                if (_exactDate != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () {
                        setState(() => _exactDate = null);
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF453A),
                        backgroundColor: const Color(
                          0xFFFF453A,
                        ).withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Clear Exact Date",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showYearSelector() {
    final int currentYear = DateTime.now().year;
    final years = [
      (currentYear + 1).toString(),
      currentYear.toString(),
      (currentYear - 1).toString(),
      (currentYear - 2).toString(),
      (currentYear - 3).toString(),
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF09090B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
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
                        setState(() {
                          _selectedYear = year;
                          _exactDate = null;
                          _lastDocument = null;
                          _hasMore = true;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedYear == year
                              ? Colors.white
                              : const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedYear == year
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          year,
                          style: GoogleFonts.inter(
                            color: _selectedYear == year
                                ? Colors.black
                                : Colors.white70,
                            fontSize: 14,
                            fontWeight: _selectedYear == year
                                ? FontWeight.w600
                                : FontWeight.w500,
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
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
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
                        setState(() {
                          _sortOrder = option.toLowerCase();
                          _lastDocument = null;
                          _hasMore = true;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: _sortOrder == option.toLowerCase()
                              ? Colors.white
                              : const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _sortOrder == option.toLowerCase()
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          option,
                          style: GoogleFonts.inter(
                            color: _sortOrder == option.toLowerCase()
                                ? Colors.black
                                : Colors.white70,
                            fontSize: 14,
                            fontWeight: _sortOrder == option.toLowerCase()
                                ? FontWeight.w600
                                : FontWeight.w500,
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
