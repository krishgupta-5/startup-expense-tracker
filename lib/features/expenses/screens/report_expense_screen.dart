import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../utils/data_helpers.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/currency_preference_service.dart';
import '../../../services/bank_account_service.dart';

class ReportExpenseScreen extends StatefulWidget {
  const ReportExpenseScreen({super.key});

  @override
  State<ReportExpenseScreen> createState() => _ReportExpenseScreenState();
}

class _ReportExpenseScreenState extends State<ReportExpenseScreen> {
  String _selectedPeriod = "weekly";

  DateTime? _customStartDate;
  DateTime? _customEndDate;

  bool _isDownloading = false;
  String _userCountryCode = '+1'; // Default to USD
  bool _isLoadingCountry = true;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final ValueNotifier<String> _categoryNotifier = ValueNotifier<String>("all");

  @override
  void initState() {
    super.initState();
    // Get currency preference synchronously for instant display
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    // Listen for currency changes
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
    _loadUserCountryCode();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _categoryNotifier.dispose();
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    super.dispose();
  }

  void _onCurrencyChanged() {
    if (mounted) {
      setState(() {
        _userCountryCode =
            CurrencyPreferenceService.getCurrencyPreferenceSync();
      });
    }
  }

  Future<void> _loadUserCountryCode() async {
    final currencyCode =
        await CurrencyPreferenceService.getCurrencyPreference();
    if (mounted) {
      setState(() {
        _userCountryCode = currencyCode;
        _isLoadingCountry = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return _isLoadingCountry
        ? CurrencyFormatter.formatByCountry(amount, '+1')
        : CurrencyFormatter.formatByCountry(amount, _userCountryCode);
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

  // --- UNIFIED MINIMAL TOAST ---
  void _showMinimalToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError
                  ? const Color(0xFFFF453A)
                  : const Color(0xFF30D158),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF141416),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        duration: const Duration(seconds: 3),
        elevation: 0,
      ),
    );
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
                  height: 48,
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

  // --- UPDATED DYNAMIC PDF EXPORT LOGIC ---
  Future<void> _exportReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMinimalToast("Error: User not logged in.", isError: true);
      return;
    }

    setState(() => _isDownloading = true);

    try {
      DateTime now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      // 1. Calculate matching date range
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

      // Normalize to full days
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      int daysInPeriod = endDate.difference(startDate).inDays;
      if (daysInPeriod <= 0) daysInPeriod = 1;

      final selectedCategory = _categoryNotifier.value;

      // 2. Fetch from Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .where('Date', isGreaterThanOrEqualTo: startDate)
          .where('Date', isLessThanOrEqualTo: endDate)
          .orderBy('Date', descending: true)
          .get();

      // 3. Aggregate Data for the PDF
      List<Map<String, dynamic>> filteredData = [];
      double totalAmount = 0;
      Map<String, double> categoryBreakdown = {};

      bool isDailyChart = daysInPeriod <= 31;
      Map<String, double> trendData = {};

      // Fetch bank accounts for reference
      final bankAccounts = await BankAccountService.getBankAccounts();
      final Map<String, String> bankAccountNames = {};
      for (var account in bankAccounts) {
        final id = account['id']?.toString() ?? '';
        final name = account['name']?.toString() ?? 'Unknown Bank';
        final last4 = account['last4']?.toString() ?? '****';
        bankAccountNames[id] = '$name ****$last4';
      }

      // Initialize trend data timeline
      if (isDailyChart) {
        for (int i = 0; i <= daysInPeriod; i++) {
          DateTime d = startDate.add(Duration(days: i));
          trendData[_formatShortDate(d)] = 0.0;
        }
      } else {
        DateTime tempDate = DateTime(startDate.year, startDate.month, 1);
        while (tempDate.isBefore(endDate) ||
            tempDate.isAtSameMomentAs(
              DateTime(endDate.year, endDate.month, 1),
            )) {
          trendData[_formatMonthYear(tempDate)] = 0.0;
          tempDate = DateTime(tempDate.year, tempDate.month + 1, 1);
        }
      }

      // Filter and Sort Firestore Data
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final category = (data['Category']?.toString() ?? 'other')
            .toLowerCase();

        if (selectedCategory != "all" && category != selectedCategory) {
          continue;
        }

        final amount = DataHelpers.safeParseDouble(data['Amount']);

        DateTime docDate = (data['Date'] as Timestamp).toDate();

        // Add to Totals
        totalAmount += amount;
        categoryBreakdown[category] =
            (categoryBreakdown[category] ?? 0.0) + amount;

        // Add to Trend
        String trendKey = isDailyChart
            ? _formatShortDate(docDate)
            : _formatMonthYear(docDate);
        if (trendData.containsKey(trendKey)) {
          trendData[trendKey] = trendData[trendKey]! + amount;
        }

        // Add to List
        final bankAccountId =
            data['bankAccount']?.toString() ??
            data['BankAccount']?.toString() ??
            '';
        final bankAccountName =
            bankAccountNames[bankAccountId] ?? 'Not specified';

        filteredData.add({
          'Date': docDate,
          'Title': data['Title'] ?? 'Unknown',
          'Category': category,
          'Amount': amount,
          'BankAccount': bankAccountName, // already resolved display name
        });
      }

      if (filteredData.isEmpty) {
        _showMinimalToast(
          "No expenses found for this specific period and category.",
          isError: true,
        );
        setState(() => _isDownloading = false);
        return;
      }

      double averageDaily = totalAmount / daysInPeriod;

      // 4. Build PDF Layout
      final pdf = pw.Document();
      final String subtitle =
          "Period: ${_formatDate(startDate)} to ${_formatDate(endDate)} | Filter: ${selectedCategory.toUpperCase()}";

      // Prepare Category Table Data
      var sortedCategories = categoryBreakdown.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final List<List<String>> categoryTableData = sortedCategories.map((e) {
        double pct = totalAmount > 0 ? e.value / totalAmount : 0;
        String displayCat = e.key.isEmpty ? "OTHER" : e.key.toUpperCase();
        return [
          displayCat,
          "${_isLoadingCountry ? CurrencyFormatter.getCurrencySymbol('+1') : CurrencyFormatter.getCurrencySymbol(_userCountryCode)} ${e.value.toStringAsFixed(2)}",
          "${(pct * 100).toStringAsFixed(1)}%",
        ];
      }).toList();

      // Prepare Trend Table Data (Filter out 0 values to keep it clean)
      final List<List<String>> trendTableData = trendData.entries
          .where((e) => e.value > 0)
          .map(
            (e) => [
              e.key,
              "${_isLoadingCountry ? CurrencyFormatter.getCurrencySymbol('+1') : CurrencyFormatter.getCurrencySymbol(_userCountryCode)} ${e.value.toStringAsFixed(2)}",
            ],
          )
          .toList();

      // Prepare Transactions Table Data
      final List<List<String>> transactionsTableData = filteredData.map((data) {
        // BankAccount is already a resolved display name (e.g. "Chase ****1234")
        final bankAccountDisplay = data['BankAccount']?.toString() ?? 'Not specified';

        return [
          _formatDate(data['Date']),
          data['Title'].toString(),
          data['Category'].toString().toUpperCase(),
          bankAccountDisplay,
          "${_isLoadingCountry ? CurrencyFormatter.getCurrencySymbol('+1') : CurrencyFormatter.getCurrencySymbol(_userCountryCode)} ${DataHelpers.safeParseDouble(data['Amount']).toStringAsFixed(2)}",
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // HEADER
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "EXPENSE REPORT",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      subtitle,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // SUMMARY SECTION
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          "TOTAL EXPENSES",
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "${_isLoadingCountry ? CurrencyFormatter.getCurrencySymbol('+1') : CurrencyFormatter.getCurrencySymbol(_userCountryCode)} ${totalAmount.toStringAsFixed(2)}",
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red800,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      width: 1,
                      height: 30,
                      color: PdfColors.grey400,
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          "AVERAGE DAILY",
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "${_isLoadingCountry ? CurrencyFormatter.getCurrencySymbol('+1') : CurrencyFormatter.getCurrencySymbol(_userCountryCode)} ${averageDaily.toStringAsFixed(2)}",
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // CATEGORY BREAKDOWN SECTION
              pw.Text(
                "CATEGORY BREAKDOWN",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Category', 'Amount', 'Percentage'],
                data: categoryTableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey600,
                ),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 30),

              // TREND SECTION
              if (trendTableData.isNotEmpty) ...[
                pw.Text(
                  "SPENDING TREND",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  headers: ['Period', 'Total Spent'],
                  data: trendTableData,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey600,
                  ),
                  cellHeight: 25,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerRight,
                  },
                ),
                pw.SizedBox(height: 30),
              ],

              // DETAILED TRANSACTIONS SECTION
              pw.Text(
                "DETAILED TRANSACTIONS",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Date',
                  'Title',
                  'Category',
                  'Bank Account',
                  'Amount',
                ],
                data: transactionsTableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
              ),
            ];
          },
        ),
      );

      // 5. Present the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'Report_${_selectedPeriod}_${_formatDate(now).replaceAll('/', '-')}.pdf',
      );
    } catch (e) {
      _showMinimalToast("Error generating report: $e", isError: true);
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  // Builds a Firestore stream filtered to the currently selected period
  // so we don't download every expense document on every rebuild.
  Stream<QuerySnapshot> _buildExpenseStream(String? uid) {
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    if (_selectedPeriod == 'weekly') {
      startDate = now.subtract(const Duration(days: 6));
    } else if (_selectedPeriod == 'monthly') {
      startDate = now.subtract(const Duration(days: 29));
    } else if (_selectedPeriod == 'quarterly') {
      startDate = now.subtract(const Duration(days: 89));
    } else if (_selectedPeriod == 'yearly') {
      startDate = now.subtract(const Duration(days: 364));
    } else if (_selectedPeriod == 'custom' &&
        _customStartDate != null &&
        _customEndDate != null) {
      startDate = _customStartDate!;
      endDate = _customEndDate!;
    } else {
      startDate = now.subtract(const Duration(days: 6));
    }

    startDate = DateTime(startDate.year, startDate.month, startDate.day);
    endDate =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    return FirebaseFirestore.instance
        .collection('expenses')
        .where('uid', isEqualTo: uid)
        .where('Date', isGreaterThanOrEqualTo: startDate)
        .where('Date', isLessThanOrEqualTo: endDate)
        .orderBy('Date', descending: true)
        .snapshots();
  }

  // --- PREMIUM SECTION LABEL HELPER ---
  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
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
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _buildExpenseStream(currentUser?.uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white38,
                            ),
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

                        bool isDailyChart = daysInPeriod <= 31;
                        Map<String, double> chartData = {};
                        List<String> chartLabels = [];

                        // --- FORCE ONLY LAST 7 DAYS IN DAILY CHART ---
                        if (isDailyChart) {
                          int displayDays = min(
                            daysInPeriod,
                            6,
                          ); // 0 to 6 = 7 days
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

                        return ValueListenableBuilder<String>(
                          valueListenable: _categoryNotifier,
                          builder: (context, selectedCategory, child) {
                            double totalExpenses = 0.0;
                            Map<String, double> categoryBreakdown = {};
                            Map<String, double> tempChartData = Map.from(
                              chartData,
                            );

                            final docs = snapshot.data?.docs ?? [];
                            for (var doc in docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final Timestamp? ts = data['Date'] as Timestamp?;
                              final DateTime docDate = ts?.toDate() ?? now;
                              final String category =
                                  (data['Category']?.toString() ?? 'other')
                                      .toLowerCase();

                              final double amount = DataHelpers.safeParseDouble(
                                data['Amount'],
                              );

                              if (docDate.isBefore(startDate) ||
                                  docDate.isAfter(endDate)) {
                                continue;
                              }
                              if (selectedCategory != "all" &&
                                  category != selectedCategory) {
                                continue;
                              }

                              totalExpenses += amount;
                              categoryBreakdown[category] =
                                  (categoryBreakdown[category] ?? 0.0) + amount;

                              if (isDailyChart) {
                                String key =
                                    "${docDate.year}-${docDate.month.toString().padLeft(2, '0')}-${docDate.day.toString().padLeft(2, '0')}";
                                if (tempChartData.containsKey(key)) {
                                  tempChartData[key] =
                                      tempChartData[key]! + amount;
                                }
                              } else {
                                String key =
                                    "${docDate.year}-${docDate.month.toString().padLeft(2, '0')}";
                                if (tempChartData.containsKey(key)) {
                                  tempChartData[key] =
                                      tempChartData[key]! + amount;
                                }
                              }
                            }

                            double averageDaily =
                                totalExpenses /
                                (daysInPeriod == 0 ? 1 : daysInPeriod);

                            return SingleChildScrollView(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
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
                                  _buildSummaryCards(
                                    totalExpenses,
                                    averageDaily,
                                  ),
                                  const SizedBox(height: 32),
                                  _buildChartSection(
                                    tempChartData.values.toList(),
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
                        );
                      },
                    ),
                  ),
                ],
              ),
              // Loader Overlay
              if (_isDownloading)
                Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
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
                color: Colors.white.withValues(
                  alpha: 0.05,
                ), // White Glass Style
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                color: Colors.white.withValues(
                  alpha: 0.05,
                ), // White Glass Style
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
        _buildSectionLabel("REPORT PERIOD"),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : const Color(0xFF141416), // Premium White Toggle
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
        _buildSectionLabel("CUSTOM DATE RANGE"),
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
      "Others",
    ];
    return ValueListenableBuilder<String>(
      valueListenable: _categoryNotifier,
      builder: (context, selectedCategory, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel("CATEGORY FILTER"),
            const SizedBox(height: 12),
            SingleChildScrollView(
              controller: _categoryScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: categories.map((category) {
                  bool isSelected = selectedCategory == category.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        _categoryNotifier.value = category.toLowerCase();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF141416), // Premium White Toggle
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontSize: 13,
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
      },
    );
  }

  Widget _buildSummaryCards(double total, double averageDaily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("SUMMARY"),
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
        borderRadius: BorderRadius.circular(20),
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
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // FIXED: FITTED BOX FOR LARGE NUMBERS
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FIXED CHART SECTION: EXPANDED BARS & WHITE THEME ---
  Widget _buildChartSection(
    List<double> data,
    List<String> labels,
    bool isDailyChart,
  ) {
    if (data.isEmpty) return const SizedBox.shrink();

    double maxVal = data.reduce(max);

    // Show a clear empty state when there are no expenses for the period
    if (maxVal == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(
            isDailyChart ? 'EXPENSE TREND (LAST 7 DAYS)' : 'EXPENSE TREND',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 240,
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bar_chart_outlined,
                  color: Colors.white.withValues(alpha: 0.15),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'No expenses for this period',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try selecting a different date range or category',
                  style: GoogleFonts.inter(
                    color: Colors.white24,
                    fontSize: 12,
                  ),
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
        _buildSectionLabel(
          isDailyChart ? "EXPENSE TREND (LAST 7 DAYS)" : "EXPENSE TREND",
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(data.length, (index) {
              double heightPercentage = data[index] / maxVal;
              if (data[index] == 0) {
                heightPercentage = 0.02;
              }

              List<String> labelParts = labels[index].split(' ');

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2.0,
                  ), // Gap between bars
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (data[index] > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              data[index] >= 1000
                                  ? "${_isLoadingCountry ? CurrencyFormatter.getCurrencySymbol('+1') : CurrencyFormatter.getCurrencySymbol(_userCountryCode)}${(data[index] / 1000).toStringAsFixed(1)}k"
                                  : "${_isLoadingCountry ? CurrencyFormatter.getCurrencySymbol('+1') : CurrencyFormatter.getCurrencySymbol(_userCountryCode)}${data[index].toStringAsFixed(0)}",
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        width: double.infinity, // Let Expanded constrain it
                        height: 120 * heightPercentage,
                        constraints: const BoxConstraints(
                          maxWidth: 36,
                        ), // Avoid super fat bars
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white, // White theme requested
                              Colors.white.withValues(alpha: 0.3),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          labelParts[0],
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (labelParts.length > 1)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            labelParts[1],
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
        _buildSectionLabel("CATEGORY BREAKDOWN"),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(24),
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
                  if (index != sortedEntries.length - 1)
                    Divider(
                      color: Colors.white.withValues(alpha: 0.04),
                      height: 1,
                    ),
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
          Expanded(
            child: Text(
              category,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                  color: Colors.white.withValues(
                    alpha: 0.1,
                  ), // Switched from Blue to White
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${(percentage * 100).toStringAsFixed(1)}%",
                  style: GoogleFonts.inter(
                    color: Colors.white, // Switched from Blue to White
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
}
