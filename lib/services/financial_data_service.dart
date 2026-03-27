import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'currency_formatter.dart';

class FinancialDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Simple in-memory cache
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Cache helper methods
  static bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    return timestamp != null &&
        DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  static T? _getCachedData<T>(String key) {
    if (_isCacheValid(key)) {
      return _cache[key] as T?;
    }
    _cache.remove(key);
    _cacheTimestamps.remove(key);
    return null;
  }

  static void _setCachedData(String key, dynamic data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  // Method to clear all cache (for testing)
  static void clearAllCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    print('DEBUG: All cache cleared');
  }

  static Future<Map<String, dynamic>> getMonthlyBurnData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final cacheKey = 'monthly_burn_${user.uid}';
    final cachedData = _getCachedData<Map<String, dynamic>>(cacheKey);
    if (cachedData != null) {
      print('DEBUG: Returning cached monthly burn data');
      return cachedData;
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    print(
      'DEBUG: Fetching monthly burn data from ${startOfMonth.toIso8601String()} to ${endOfMonth.toIso8601String()}',
    );

    try {
      // Run all queries in parallel for better performance
      final futures = await Future.wait([
        // Get expenses for current month
        _firestore
            .collection('expenses')
            .where('uid', isEqualTo: user.uid)
            .where(
              'Date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
            )
            .where('Date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
            .get(),
        // Get budget data
        _getBudgetData(user.uid),
        // Get revenue data
        _getMonthlyRevenue(user.uid, startOfMonth, endOfMonth),
        // Get trend data
        _getSixMonthTrend(user.uid),
        // Get team member data for salaries
        _firestore
            .collection('team_members')
            .where('uid', isEqualTo: user.uid)
            .get(),
      ]);

      final expensesSnapshot = futures[0] as QuerySnapshot;
      final budgetComparison = futures[1] as Map<String, dynamic>;
      final revenue = futures[2] as double;
      final trendData = futures[3] as List<Map<String, dynamic>>;
      final teamMembersSnapshot = futures[4] as QuerySnapshot;

      print('DEBUG: Found ${expensesSnapshot.docs.length} expenses');
      print('DEBUG: Budget data keys: ${budgetComparison.keys.toList()}');
      print('DEBUG: Revenue: $revenue');
      print('DEBUG: Trend data length: ${trendData.length}');
      print('DEBUG: Found ${teamMembersSnapshot.docs.length} team members');

      // Process data efficiently
      double totalExpenses = 0;
      double salariesTotal = 0;
      Map<String, double> categoryTotals = {};
      Map<String, double> vendorTotals = {};

      // Process expenses (already filtered by date in query)
      for (var doc in expensesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final amount = double.tryParse(data['Amount']?.toString() ?? '0') ?? 0;
        final category = data['Category']?.toString() ?? 'Other';
        final vendor = data['Vendor']?.toString() ?? 'Unknown';

        totalExpenses += amount;
        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
        vendorTotals[vendor] = (vendorTotals[vendor] ?? 0) + amount;

        final expenseDate = (data['Date'] as Timestamp?)?.toDate();
        print(
          'DEBUG: Processed expense - Amount: $amount, Category: $category, Date: $expenseDate',
        );
      }

      // Calculate salaries from actual team members
      for (var doc in teamMembersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final salary = double.tryParse(data['salary']?.toString() ?? '0') ?? 0;
        salariesTotal += salary;

        print('DEBUG: Team member salary: $salary');
      }

      print('DEBUG: Total expenses: $totalExpenses');
      print('DEBUG: Category totals: $categoryTotals');
      print('DEBUG: Salaries total: $salariesTotal');

      // Calculate monthly burn metrics
      final grossBurn = totalExpenses + salariesTotal;
      final netBurn = grossBurn - revenue;

      print('DEBUG: Gross burn: $grossBurn');
      print('DEBUG: Net burn: $netBurn');

      final result = {
        'grossBurn': grossBurn,
        'netBurn': netBurn,
        'revenue': revenue,
        'categoryBreakdown': categoryTotals,
        'vendorBreakdown': vendorTotals,
        'teamCosts': salariesTotal,
        'trendData': trendData,
        'budgetComparison': budgetComparison,
        'totalExpenses': totalExpenses,
        'month': now.month,
        'year': now.year,
      };

      // Cache the result
      _setCachedData(cacheKey, result);
      return result;
    } catch (e) {
      print('ERROR in getMonthlyBurnData: $e');
      throw Exception('Failed to fetch financial data: $e');
    }
  }

  static Future<double> _getMonthlyRevenue(
    String uid,
    DateTime start,
    DateTime end,
  ) async {
    try {
      // Assuming revenue is stored in a 'revenue' collection or as negative expenses
      final revenueSnapshot = await _firestore
          .collection('revenue')
          .where('uid', isEqualTo: uid)
          .where('Date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('Date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      double totalRevenue = 0;
      for (var doc in revenueSnapshot.docs) {
        final amount =
            double.tryParse(doc.data()['Amount']?.toString() ?? '0') ?? 0;
        totalRevenue += amount;
      }

      return totalRevenue;
    } catch (e) {
      // If no revenue collection exists, return 0
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> _getSixMonthTrend(
    String uid,
  ) async {
    final now = DateTime.now();
    final trendData = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);

      try {
        // Get expenses for the month
        final expensesSnapshot = await _firestore
            .collection('expenses')
            .where('uid', isEqualTo: uid)
            .where('Date', isGreaterThanOrEqualTo: Timestamp.fromDate(month))
            .where('Date', isLessThan: Timestamp.fromDate(nextMonth))
            .get();

        double expensesTotal = 0;
        for (var doc in expensesSnapshot.docs) {
          final amount =
              double.tryParse(doc.data()['Amount']?.toString() ?? '0') ?? 0;
          expensesTotal += amount;
        }

        // Get team/salary data for the month
        final teamSnapshot = await _firestore
            .collection('team_members')
            .where('uid', isEqualTo: uid)
            .get();

        double salariesTotal = 0;
        for (var doc in teamSnapshot.docs) {
          final salary =
              double.tryParse(doc.data()['salary']?.toString() ?? '0') ?? 0;
          salariesTotal += salary;
        }

        // Calculate total burn (expenses + salaries)
        final totalBurn = expensesTotal + salariesTotal;

        trendData.add({
          'month': _getMonthAbbreviation(month.month),
          'amount': totalBurn,
          'isCurrentMonth': i == 0,
        });
      } catch (e) {
        // Add default data if there's an error
        trendData.add({
          'month': _getMonthAbbreviation(month.month),
          'amount': 35000.0 + (i * 2000), // Add some variation for demo
          'isCurrentMonth': i == 0,
        });
      }
    }

    return trendData;
  }

  static Future<Map<String, dynamic>> _getBudgetData(String uid) async {
    try {
      // Fetch all teams for the user
      final teamsSnapshot = await _firestore
          .collection('teams')
          .where('uid', isEqualTo: uid)
          .get();

      if (teamsSnapshot.docs.isEmpty) {
        print('DEBUG: No teams found, returning empty budget');
        return {};
      }

      // Aggregate budget data by team
      Map<String, dynamic> budgetData = {};
      double totalBudget = 0.0;

      for (var doc in teamsSnapshot.docs) {
        final teamData = doc.data();
        final teamName = teamData['teamName'] as String? ?? 'Unknown Team';
        final monthlyBudget = (teamData['monthlyBudget'] ?? 0.0) as double;

        if (monthlyBudget > 0) {
          budgetData[teamName] = monthlyBudget;
          totalBudget += monthlyBudget;
        }

        print('DEBUG: Team $teamName has budget: $monthlyBudget');
      }

      // Add total
      budgetData['Total'] = totalBudget;

      print('DEBUG: Final budget data: $budgetData');
      return budgetData;
    } catch (e) {
      print('DEBUG: Error fetching team budget data: $e');
      return {};
    }
  }

  static String _getMonthAbbreviation(int month) {
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

  // Helper method to format currency properly
  static String _formatCurrency(double amount, {String countryCode = '+1'}) {
    return CurrencyFormatter.formatByCountry(amount, countryCode);
  }

  static Future<Map<String, dynamic>> getTeamCostDistribution() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final cacheKey = 'team_cost_${user.uid}';
    final cachedData = _getCachedData<Map<String, dynamic>>(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    try {
      // Get all teams for the user
      final teamsSnapshot = await _firestore
          .collection('teams')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (teamsSnapshot.docs.isEmpty) {
        final emptyResult = {'teamCosts': [], 'totalCost': 0};
        _setCachedData(cacheKey, emptyResult);
        return emptyResult;
      }

      // Get all members in parallel for better performance
      final memberFutures = teamsSnapshot.docs.map((teamDoc) async {
        final membersSnapshot = await _firestore
            .collection('members')
            .where('teamId', isEqualTo: teamDoc.id)
            .get();

        final teamData = teamDoc.data();
        final teamName = teamData['teamName']?.toString() ?? 'Unknown Team';

        double teamCost = 0;
        for (var memberDoc in membersSnapshot.docs) {
          final memberData = memberDoc.data();
          final cost =
              double.tryParse(memberData['monthlyCost']?.toString() ?? '0') ??
              0;
          final status = memberData['status']?.toString() ?? 'Active';

          if (status == 'Active') {
            teamCost += cost;
          }
        }

        return {'name': teamName, 'cost': teamCost};
      }).toList();

      final teamResults = await Future.wait(memberFutures);

      Map<String, double> departmentCosts = {};
      double totalCost = 0;

      for (var result in teamResults) {
        departmentCosts[result['name'] as String] = result['cost'] as double;
        totalCost += result['cost'] as double;
      }

      // Convert to list format for display
      final teamCostList = departmentCosts.entries
          .map(
            (entry) => {
              'name': entry.key,
              'cost': _formatCurrency(entry.value),
              'pct': totalCost > 0 ? (entry.value / totalCost) : 0.0,
            },
          )
          .toList();

      // Ensure percentages add up to 1.0 by normalizing
      if (totalCost > 0 && teamCostList.isNotEmpty) {
        final calculatedTotal = teamCostList.fold<double>(
          0.0,
          (sum, team) => sum + (team['pct'] as double),
        );

        // Normalize if there are floating point precision issues
        if ((calculatedTotal - 1.0).abs() > 0.001) {
          for (var team in teamCostList) {
            team['pct'] = (team['pct'] as double) / calculatedTotal;
          }
        }
      }

      // Sort by cost (highest first)
      teamCostList.sort(
        (a, b) => (b['pct'] as double).compareTo(a['pct'] as double),
      );

      final result = {'teamCosts': teamCostList, 'totalCost': totalCost};
      _setCachedData(cacheKey, result);
      return result;
    } catch (e) {
      throw Exception('Failed to fetch team cost data: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getRawTeamsData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final cacheKey = 'raw_teams_${user.uid}';
    final cachedData = _getCachedData<List<Map<String, dynamic>>>(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    try {
      final teamsSnapshot = await _firestore
          .collection('teams')
          .where('uid', isEqualTo: user.uid)
          .get();

      final result = teamsSnapshot.docs.map((doc) => doc.data()).toList();
      _setCachedData(cacheKey, result);
      return result;
    } catch (e) {
      throw Exception('Failed to fetch teams data: $e');
    }
  }

  static Future<Map<String, double>> getActualSpendingPerTeam() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final cacheKey = 'team_spending_${user.uid}';
    final cachedData = _getCachedData<Map<String, double>>(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Run queries in parallel
      final futures = await Future.wait([
        // Get all expenses for current month
        _firestore
            .collection('expenses')
            .where('uid', isEqualTo: user.uid)
            .get(),
        // Get all teams to map team names
        _firestore.collection('teams').where('uid', isEqualTo: user.uid).get(),
      ]);

      final expensesSnapshot = futures[0] as QuerySnapshot;
      final teamsSnapshot = futures[1] as QuerySnapshot;

      Map<String, String> teamIdToName = {};
      for (var teamDoc in teamsSnapshot.docs) {
        final teamData = teamDoc.data() as Map<String, dynamic>?;
        if (teamData == null) continue;

        final teamName = teamData['teamName']?.toString() ?? 'Unknown';
        teamIdToName[teamDoc.id] = teamName;
      }

      Map<String, double> teamSpending = {};

      // Process expenses and categorize by team
      for (var doc in expensesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final amount = double.tryParse(data['Amount']?.toString() ?? '0') ?? 0;
        final category = data['Category']?.toString() ?? 'Other';
        final teamName = data['TeamName']?.toString();
        final expenseDate = (data['Date'] as Timestamp?)?.toDate();

        // Filter by date in code
        if (expenseDate != null &&
            expenseDate.isAfter(
              startOfMonth.subtract(const Duration(days: 1)),
            ) &&
            expenseDate.isBefore(endOfMonth.add(const Duration(days: 1)))) {
          // Use TeamName field if it exists, otherwise map by category
          String assignedTeam;
          if (teamName != null && teamName.isNotEmpty) {
            assignedTeam = teamName;
          } else {
            assignedTeam = _mapCategoryToTeam(category, teamIdToName);
          }

          teamSpending[assignedTeam] =
              (teamSpending[assignedTeam] ?? 0) + amount;
        }
      }

      _setCachedData(cacheKey, teamSpending);
      return teamSpending;
    } catch (e) {
      throw Exception('Failed to fetch team spending: $e');
    }
  }

  static String _mapCategoryToTeam(
    String category,
    Map<String, String> teamIdToName,
  ) {
    // Normalize category for easier matching
    final normalizedCategory = category.toLowerCase();

    // Try exact team name matches first
    for (String teamName in teamIdToName.values) {
      if (normalizedCategory.contains(teamName.toLowerCase()) ||
          teamName.toLowerCase().contains(normalizedCategory)) {
        return teamName;
      }
    }

    // Comprehensive mapping for website development categories
    if (normalizedCategory.contains('website') ||
        normalizedCategory.contains('developer') ||
        normalizedCategory.contains('development') ||
        normalizedCategory.contains('web') ||
        normalizedCategory.contains('programming') ||
        normalizedCategory.contains('coding') ||
        normalizedCategory.contains('frontend') ||
        normalizedCategory.contains('backend') ||
        normalizedCategory.contains('fullstack') ||
        normalizedCategory.contains('ui') ||
        normalizedCategory.contains('ux') ||
        normalizedCategory.contains('design')) {
      return teamIdToName.values.firstWhere(
        (name) =>
            name.toLowerCase().contains('website') ||
            name.toLowerCase().contains('developer'),
        orElse: () => 'Website Developer',
      );
    } else if (normalizedCategory.contains('marketing') ||
        normalizedCategory.contains('advertising') ||
        normalizedCategory.contains('promotion') ||
        normalizedCategory.contains('social media')) {
      return teamIdToName.values.firstWhere(
        (name) => name.toLowerCase().contains('marketing'),
        orElse: () => 'Marketing',
      );
    } else if (normalizedCategory.contains('testing') ||
        normalizedCategory.contains('qa') ||
        normalizedCategory.contains('quality') ||
        normalizedCategory.contains('test') ||
        normalizedCategory.contains('testing') ||
        normalizedCategory.contains('automation') ||
        normalizedCategory.contains('manual testing')) {
      return teamIdToName.values.firstWhere(
        (name) =>
            name.toLowerCase().contains('testing') ||
            name.toLowerCase().contains('qa'),
        orElse: () => 'Testing',
      );
    } else if (normalizedCategory.contains('engineering') ||
        normalizedCategory.contains('tech') ||
        normalizedCategory.contains('salaries') ||
        normalizedCategory.contains('salary') ||
        normalizedCategory.contains('infrastructure') ||
        normalizedCategory.contains('servers')) {
      // Check if we have a Website Developer team first
      if (teamIdToName.values.any(
        (name) =>
            name.toLowerCase().contains('website') ||
            name.toLowerCase().contains('developer'),
      )) {
        return teamIdToName.values.firstWhere(
          (name) =>
              name.toLowerCase().contains('website') ||
              name.toLowerCase().contains('developer'),
          orElse: () => 'Engineering',
        );
      }
      return teamIdToName.values.firstWhere(
        (name) =>
            name.toLowerCase().contains('engineering') ||
            name.toLowerCase().contains('tech'),
        orElse: () => 'Engineering',
      );
    } else if (normalizedCategory.contains('operations') ||
        normalizedCategory.contains('office') ||
        normalizedCategory.contains('admin')) {
      return teamIdToName.values.firstWhere(
        (name) =>
            name.toLowerCase().contains('operations') ||
            name.toLowerCase().contains('admin'),
        orElse: () => 'Operations',
      );
    }

    // Fallback to a general "Other" or first available team if no specific match
    return teamIdToName.isNotEmpty ? teamIdToName.values.first : 'Other';
  }
}
