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

    // Use currency service for PDF formatting with fallback for unsupported symbols
    String getPdfCurrencySymbol(double amount) {
      final userCurrencyCode =
          CurrencyPreferenceService.getCurrencyPreferenceSync();
      final formattedAmount = CurrencyFormatter.formatByCountry(
        amount,
        userCurrencyCode,
      );

      // Handle currency symbols that might not render properly in PDF
      switch (userCurrencyCode) {
        case '+91': // INR - ₹ might not render in PDF
          return 'Rs.${amount.toStringAsFixed(2)}';
        case '+971': // AED - د.إ might not render in PDF
          return 'AED ${amount.toStringAsFixed(2)}';
        case '+49': // EUR - € might not render in PDF
        case '+33': // EUR - € might not render in PDF
          return 'EUR ${amount.toStringAsFixed(2)}';
        case '+81': // JPY - ¥ might not render in PDF
          return 'JPY ${amount.toStringAsFixed(0)}';
        case '+65': // SGD - S$ might not render in PDF
          return 'SGD ${amount.toStringAsFixed(2)}';
        default:
          // For USD, GBP, AUD - symbols usually work fine in PDF
          return formattedAmount;
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

      // 2. Fetch Data from Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .where('Date', isGreaterThanOrEqualTo: startDate)
          .where('Date', isLessThanOrEqualTo: endDate)
          .orderBy('Date', descending: true)
          .get();

      final expenses = querySnapshot.docs;

      if (expenses.isEmpty) {
        _showMinimalToast("No expenses found for this period.", isError: true);
        setState(() => _isDownloading = false);
        return;
      }

      // 3. Generate PDF
      final pdf = pw.Document();
      double totalAmount = 0;

      // Map Firestore data to PDF table rows
      final List<List<String>> tableData = expenses
          .map((doc) {
            final data = doc.data(); // Standard dynamic map
            final amount = double.tryParse(data['Amount'].toString()) ?? 0.0;
            totalAmount += amount;

            final date = (data['Date'] as Timestamp).toDate();
            final dateStr = "${date.day}/${date.month}/${date.year}";

            return [
              dateStr,
              data['Title']?.toString() ?? 'Unknown',
              data['Category']?.toString().toUpperCase() ?? 'N/A',
              _getBankAccountDisplay(data), // Using the new helper!
              getPdfCurrencySymbol(amount),
            ];
          })
          .cast<List<String>>()
          .toList();

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

              // PDF Table
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Title', 'Category', 'Account', 'Amount'],
                data: tableData,
                border: null,
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
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
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
