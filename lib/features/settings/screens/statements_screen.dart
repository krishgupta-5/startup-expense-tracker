import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Ensure these paths match your project structure
import '../../../../services/currency_formatter.dart';
import '../../../../services/currency_preference_service.dart';
import '../../../../services/bank_account_service.dart';
import '../../../../utils/expense_expansion_helper.dart';

class ExpensesExportScreen extends StatefulWidget {
  const ExpensesExportScreen({super.key});

  @override
  State<ExpensesExportScreen> createState() => _ExpensesExportScreenState();
}

class _ExpensesExportScreenState extends State<ExpensesExportScreen> {
  bool _isDownloading = false;

  // Helper to get month name
  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  // Helper to format bank account display
  String _getBankAccountDisplay(Map<String, dynamic> transactionData) {
    // Check for bank account ID
    final bankAccountId =
        transactionData['bankAccount'] as String? ??
        transactionData['BankAccount'] as String?;

    if (bankAccountId != null) {
      // Check if it's a cash transaction (either "Cash-" or "Cash")
      if (bankAccountId == 'Cash-' || bankAccountId == 'Cash') {
        return 'Cash';
      }

      // For bank accounts, try to format them properly
      if (bankAccountId.contains('-')) {
        final parts = bankAccountId.split('-');
        if (parts.length >= 2) {
          final bankName = parts[0];
          final rawLast4 = parts[1];
          final last4 = rawLast4.isNotEmpty
              ? BankAccountService.extractLast4(rawLast4)
              : '';
          return last4.isNotEmpty ? '$bankName ****$last4' : bankName;
        }
      }

      // Ensure PDF-safe text by removing any problematic characters
      return bankAccountId.replaceAll(RegExp(r'[^\w\s\-\.\*]'), '');
    }

    // Check if it's a cash payment
    final paymentMethod = transactionData['PaymentMethod'] as String?;
    if (paymentMethod == 'cash') {
      return 'Cash';
    }

    return 'N/A';
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

  // --- REPORT GENERATION LOGIC ---
  Future<void> _downloadReport(String reportType) async {
    setState(() => _isDownloading = true);

    // PDF-safe currency formatter: Unicode symbols may not render in the
    // default PDF font, so we use ASCII-safe fallbacks for ALL currencies.
    String getPdfCurrencySymbol(double amount) {
      final userCurrencyCode =
          CurrencyPreferenceService.getCurrencyPreferenceSync();

      switch (userCurrencyCode) {
        case '+1': // USD
          return '\$${amount.toStringAsFixed(2)}';
        case '+91': // INR - ₹ doesn't render in PDF
          return 'Rs.${amount.toStringAsFixed(2)}';
        case '+44': // GBP - £ may not render in PDF
          return 'GBP ${amount.toStringAsFixed(2)}';
        case '+61': // AUD
          return 'A\$${amount.toStringAsFixed(2)}';
        case '+81': // JPY - ¥ doesn't render in PDF
          return 'JPY ${amount.toStringAsFixed(0)}';
        case '+49': // EUR (Germany) - € doesn't render in PDF
        case '+33': // EUR (France)
          return 'EUR ${amount.toStringAsFixed(2)}';
        case '+971': // AED - د.إ doesn't render in PDF
          return 'AED ${amount.toStringAsFixed(2)}';
        case '+65': // SGD
          return 'S\$${amount.toStringAsFixed(2)}';
        default:
          return '\$${amount.toStringAsFixed(2)}';
      }
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;
      String reportTitle = "";

      // 1. Calculate Date Ranges Based on Report Type
      if (reportType == "Monthly") {
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        reportTitle =
            "Monthly Expenses - ${_getMonthName(now.month)} ${now.year}";
      } else if (reportType == "Quarterly") {
        final currentQuarter = ((now.month - 1) ~/ 3) + 1;
        final startMonth = (currentQuarter - 1) * 3 + 1;
        startDate = DateTime(now.year, startMonth, 1);
        // Safe end: last day of the quarter's last month, handles Dec overflow
        final endMonth = startMonth + 2;
        final endYear = endMonth > 12 ? now.year + 1 : now.year;
        final safeEndMonth = endMonth > 12 ? endMonth - 12 : endMonth;
        endDate = DateTime(endYear, safeEndMonth + 1, 0, 23, 59, 59);
        reportTitle = "Quarterly Expenses - Q$currentQuarter ${now.year}";
      } else {
        // Annual (Assuming Financial Year April - March)
        final isNewFY = now.month >= 4;
        final startYear = isNewFY ? now.year : now.year - 1;
        startDate = DateTime(startYear, 4, 1);
        endDate = DateTime(startYear + 1, 3, 31, 23, 59, 59);
        reportTitle =
            "Annual Expenses - FY $startYear-${(startYear + 1).toString().substring(2)}";
      }

      // 2. Fetch Data from Firestore and expand in memory
      final querySnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .get();

      final mappedExpenses = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();

      final expanded = ExpenseExpansionHelper.expandExpenses(
        mappedExpenses,
        maxDate: endDate,
      );

      final expenses = expanded.where((data) {
        final dateVal = data['Date'] ?? data['date'];
        DateTime? dt;
        if (dateVal is Timestamp) {
          dt = dateVal.toDate();
        } else if (dateVal is DateTime) {
          dt = dateVal;
        }
        if (dt == null) return false;
        return dt.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            dt.isBefore(endDate.add(const Duration(seconds: 1)));
      }).toList();

      // Sort descending by date
      expenses.sort((a, b) {
        final aDateVal = a['Date'] ?? a['date'];
        final bDateVal = b['Date'] ?? b['date'];
        DateTime? aDt = aDateVal is Timestamp ? aDateVal.toDate() : aDateVal as DateTime?;
        DateTime? bDt = bDateVal is Timestamp ? bDateVal.toDate() : bDateVal as DateTime?;
        if (aDt == null && bDt == null) return 0;
        if (aDt == null) return 1;
        if (bDt == null) return -1;
        return bDt.compareTo(aDt);
      });

      if (expenses.isEmpty) {
        _showMinimalToast("No expenses found for this period.", isError: true);
        setState(() => _isDownloading = false);
        return;
      }

      // 3. Generate PDF
      final pdf = pw.Document();
      double totalAmount = 0;

      // Helper to build a single table cell
      pw.Widget buildCell(
        String text, {
        pw.Alignment alignment = pw.Alignment.centerLeft,
        PdfColor? textColor,
        pw.FontWeight fontWeight = pw.FontWeight.normal,
      }) {
        return pw.Container(
          height: 30,
          alignment: alignment,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 10,
              color: textColor ?? PdfColors.black,
              fontWeight: fontWeight,
            ),
          ),
        );
      }

      // Build table rows with per-row green for funding
      final List<pw.TableRow> tableRows = [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          children: [
            'Date', 'Title', 'Category', 'Account', 'Amount',
          ].asMap().entries.map((entry) {
            return buildCell(
              entry.value,
              alignment: entry.key == 4
                  ? pw.Alignment.centerRight
                  : pw.Alignment.centerLeft,
              textColor: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            );
          }).toList(),
        ),
        // Data rows
        ...expenses.map((data) {
          final amount = double.tryParse(data['Amount'].toString()) ?? 0.0;
          final category = data['Category']?.toString().toLowerCase() ?? '';
          final isFunding = data['isFunding'] == true || category == 'funding';
          if (!isFunding) {
            totalAmount += amount;
          }

          final dateVal = data['Date'] ?? data['date'];
          final DateTime date = dateVal is Timestamp ? dateVal.toDate() : dateVal as DateTime;
          final dateStr = "${date.day}/${date.month}/${date.year}";
          final amountStr = getPdfCurrencySymbol(amount);
          final displayAmount = isFunding ? '+$amountStr' : amountStr;
          final rowColor = isFunding
              ? const PdfColor(0.16, 0.55, 0.25) // green700
              : PdfColors.black;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isFunding
                  ? const PdfColor(0.91, 0.98, 0.92) // light green tint
                  : null,
              border: const pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
              ),
            ),
            children: [
              buildCell(dateStr, textColor: rowColor),
              buildCell(
                data['Title']?.toString() ?? 'Unknown',
                textColor: rowColor,
              ),
              buildCell(
                data['Category']?.toString().toUpperCase() ?? 'N/A',
                textColor: rowColor,
              ),
              buildCell(
                _getBankAccountDisplay(data),
                textColor: rowColor,
              ),
              buildCell(
                displayAmount,
                alignment: pw.Alignment.centerRight,
                textColor: isFunding
                    ? const PdfColor(0.13, 0.55, 0.13) // green
                    : PdfColors.black,
                fontWeight: isFunding
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ],
          );
        }),
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // PDF Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "EXPENSE REPORT",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      reportTitle,
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // PDF Table with per-row funding colors
              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(70),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FixedColumnWidth(80),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FixedColumnWidth(100),
                },
                children: tableRows,
              ),
              pw.SizedBox(height: 20),

              // PDF Total
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Total: ${getPdfCurrencySymbol(totalAmount)}",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      // 4. Print / Share / Download the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${reportTitle.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      _showMinimalToast("Error generating report.", isError: true);
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();

    final String currentMonthYear = "${_getMonthName(now.month)} ${now.year}";
    final int currentQuarter = ((now.month - 1) ~/ 3) + 1;
    final String currentQuarterStr = "Q$currentQuarter ${now.year}";
    final bool isNewFY = now.month >= 4;
    final int startYear = isNewFY ? now.year : now.year - 1;
    final String currentFY =
        "FY $startYear-${(startYear + 1).toString().substring(2)}";

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32),
                          Text(
                            "Expense Details",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Download and manage your expense reports",
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 40),

                          _buildSectionLabel("AVAILABLE EXPENSE REPORTS"),

                          // Monthly Button
                          _buildStatementCard(
                            title: "Monthly Expenses",
                            period: currentMonthYear,
                            description:
                                "Download detailed expense breakdown for $currentMonthYear",
                            icon: Icons.receipt_long,
                            onTap: () => _downloadReport("Monthly"),
                          ),
                          const SizedBox(height: 16),

                          // Quarterly Button
                          _buildStatementCard(
                            title: "Quarterly Expenses",
                            period: currentQuarterStr,
                            description:
                                "Comprehensive quarterly spending analysis",
                            icon: Icons.pie_chart_outline,
                            onTap: () => _downloadReport("Quarterly"),
                          ),
                          const SizedBox(height: 16),

                          // Annual Button
                          _buildStatementCard(
                            title: "Annual Expense Summary",
                            period: currentFY,
                            description:
                                "Complete annual overview of all expenses",
                            icon: Icons.summarize,
                            onTap: () => _downloadReport("Annual"),
                          ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Loading Overlay
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
            "Downloads",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 44), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildStatementCard({
    required String title,
    required String period,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Icon(icon, color: Colors.white70, size: 20),
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
                      ),
                      const SizedBox(height: 2),
                      Text(
                        period,
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Icon(
                    Icons.download,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
