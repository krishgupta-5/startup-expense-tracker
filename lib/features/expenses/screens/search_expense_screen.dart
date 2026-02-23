import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    'transport': 'Transport',
    'design': 'Design',
    'others': 'Others',
  };

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year.toString();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 4. SMART LOCAL FILTER & SORT LOGIC
  List<QueryDocumentSnapshot> _filterAndSortDocs(
    List<QueryDocumentSnapshot> docs,
  ) {
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      if (data['Date'] == null || data['Date'] is! Timestamp) return false;
      final txDate = (data['Date'] as Timestamp).toDate();

      // A. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final title = (data['Title'] ?? '').toString().toLowerCase();
        if (!title.contains(_searchQuery.toLowerCase())) return false;
      }

      // B. Category Filter
      if (_selectedCategoryKey != 'all') {
        final txCat = (data['Category'] ?? '').toString().toLowerCase();
        if (txCat != _selectedCategoryKey) return false;
      }

      // C. Date Filter (Exact Day OR Month/Year)
      if (_exactDate != null) {
        if (txDate.year != _exactDate!.year ||
            txDate.month != _exactDate!.month ||
            txDate.day != _exactDate!.day) {
          return false;
        }
      } else {
        // Year Match
        if (txDate.year.toString() != _selectedYear) return false;
        // Month Match
        if (_selectedMonthKey != 'all') {
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
          if (txDate.month != monthMap[_selectedMonthKey]) return false;
        }
      }

      return true;
    }).toList();

    // D. Sort Logic
    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      final dateA = (dataA['Date'] as Timestamp).toDate();
      final dateB = (dataB['Date'] as Timestamp).toDate();

      if (_sortOrder == 'newest') {
        return dateB.compareTo(dateA); // Descending
      } else {
        return dateA.compareTo(dateB); // Ascending
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

                    // Date Picker Button (Highlights Green if active)
                    GestureDetector(
                      onTap: () => _showDatePicker(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _exactDate != null
                              ? const Color(0xFF30D158).withValues(alpha: 0.15)
                              : const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _exactDate != null
                                ? const Color(0xFF30D158)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Icon(
                          Icons.calendar_month,
                          color: _exactDate != null
                              ? const Color(0xFF30D158)
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _months.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                        });
                      },
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

              // --- RESULTS LIST (FIREBASE STREAM) ---
              Expanded(child: _buildFirebaseResults()),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildFirebaseResults() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildEmptyState("User not logged in");

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .snapshots(),
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
          return _buildEmptyState("Failed to load data");
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("No expenses found");
        }

        // Apply Local Filtering and Sorting
        final docs = _filterAndSortDocs(snapshot.data!.docs);

        if (docs.isEmpty) {
          return _buildEmptyState("No matching expenses found");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _buildTransactionRow(docs[index]);
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
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white38,
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                // Add a clear button when typing
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

  Widget _buildTransactionRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final id = doc.id;

    final title = data['Title'] ?? 'Unnamed Expense';
    final amount = data['Amount']?.toString() ?? '0.00';

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
            Text(
              "-₹$amount",
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.filter_list_off, color: Colors.white12, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
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
                const SizedBox(height: 16),

                // ShadCN Calendar
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
                      });
                      Navigator.pop(context);
                    }
                  },
                ),

                // Option to Clear Date Filter
                if (_exactDate != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        setState(() => _exactDate = null);
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
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
                          _exactDate =
                              null; // Clear exact date if changing year manually
                        });
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
