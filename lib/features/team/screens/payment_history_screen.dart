import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'transaction_details_screen.dart'; // Make sure to import the new screen
import '../../../../services/currency_formatter.dart';
import '../../../../services/currency_preference_service.dart';
import '../../../../services/bank_account_service.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final DateTime joiningDate;
  final double salary;
  final String memberName;
  final String memberId;

  const PaymentHistoryScreen({
    super.key,
    required this.joiningDate,
    required this.salary,
    required this.memberName,
    required this.memberId,
  });

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _isDownloading = false;

  // Helper to format currency
  String _formatCurrency(double amount) {
    final userCurrencyCode =
        CurrencyPreferenceService.getCurrencyPreferenceSync();
    return CurrencyFormatter.formatByCountry(amount, userCurrencyCode);
  }

  // Helper to format Firestore Timestamp
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown Date";
    final DateTime dt = timestamp.toDate();
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
    return "${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}";
  }

  // --- PAYMENT HISTORY DOWNLOAD LOGIC ---
  Future<void> _downloadPaymentHistory() async {
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

      // Fetch all payment data for this member
      final querySnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: user.uid)
          .where('memberId', isEqualTo: widget.memberId)
          .where('Category', isEqualTo: 'salary')
          .get();

      final payments = querySnapshot.docs;

      if (payments.isEmpty) {
        _showMessage("No payment history found for this member.");
        setState(() => _isDownloading = false);
        return;
      }

      // Sort payments by date (ascending for chronological order in PDF)
      payments.sort((a, b) {
        final Timestamp? dateA = a['Date'] as Timestamp?;
        final Timestamp? dateB = b['Date'] as Timestamp?;
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

      // Generate PDF
      final pdf = pw.Document();
      double totalAmount = 0;

      // Map Firestore data to PDF table rows
      final List<List<String>> tableData = payments
          .map((doc) {
            final data = doc.data();
            final amount = double.tryParse(data['Amount'].toString()) ?? 0.0;
            totalAmount += amount;

            final date = (data['Date'] as Timestamp).toDate();
            final dateStr = "${date.day}/${date.month}/${date.year}";

            final title = data['Title']?.toString() ?? 'Unknown';
            final paymentType = title.contains("Advance")
                ? "Advance"
                : "Salary";

            // Format bank account like transaction details
            String paymentMethod = _getBankAccountDisplay(data);

            return [
              dateStr,
              paymentType,
              paymentMethod,
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
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "PAYMENT HISTORY REPORT",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      "Member: ${widget.memberName}",
                      style: const pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      "Joining Date: ${_formatDate(Timestamp.fromDate(widget.joiningDate))}",
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
                headers: ['Date', 'Type', 'Payment Method', 'Amount'],
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
                  3: pw.Alignment.centerRight,
                },
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // PDF Summary
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Total Payments: ${payments.length}",
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      "Total Amount: ${getPdfCurrencySymbol(totalAmount)}",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Print / Share / Download the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${widget.memberName}_Payment_History.pdf',
      );
    } catch (e) {
      _showMessage("Error generating payment history: $e");
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF141416),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      body: Stack(
        children: [
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 1. Header
                  _buildHeader(context),

                  // 2. Content with StreamBuilder
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('expenses')
                          .where('uid', isEqualTo: currentUser?.uid)
                          // Fix #7: Filter server-side — avoids reading all expenses
                          .where('memberId', isEqualTo: widget.memberId)
                          .where('Category', isEqualTo: 'salary')
                          .snapshots(),
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
                              "Error loading payment history.",
                              style: GoogleFonts.inter(color: Colors.redAccent),
                            ),
                          );
                        }

                        // Extract and filter data
                        final allDocs = snapshot.data?.docs ?? [];
                        List<Map<String, dynamic>> memberPayments = [];
                        double totalPaid = 0.0;

                        for (var doc in allDocs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final String category =
                              data['Category']?.toString().toLowerCase() ?? '';
                          final String title = data['Title']?.toString() ?? '';

                          // Filter: Must be a salary expense AND match the member's ID
                          if (category == 'salary' &&
                              data['memberId'] == widget.memberId) {
                            final double amt = data['Amount'] is int
                                ? (data['Amount'] as int).toDouble()
                                : (data['Amount'] as double? ?? 0.0);

                            totalPaid += amt;
                            memberPayments.add({
                              "id": doc.id, // Store doc ID for the details page
                              "rawData":
                                  data, // Store raw map for the details page
                              "rawDate": data['Date'] as Timestamp?,
                              "date": _formatDate(data['Date'] as Timestamp?),
                              "amt": _formatCurrency(amt),
                              "status": "Completed",
                              "title": title.contains("Advance")
                                  ? "Advance Payout"
                                  : "Salary Payout",
                            });
                          }
                        }

                        // Sort newest first
                        memberPayments.sort((a, b) {
                          final Timestamp? dateA = a["rawDate"];
                          final Timestamp? dateB = b["rawDate"];
                          if (dateA == null || dateB == null) return 0;
                          return dateB.compareTo(dateA);
                        });

                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start, // Align to left
                            children: [
                              const SizedBox(height: 32),

                              // --- SUMMARY CARD ---
                              _buildSummaryCard(
                                memberPayments.length,
                                totalPaid,
                              ),

                              const SizedBox(height: 32),

                              // --- PAYMENT LIST ---
                              if (memberPayments.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Center(
                                    child: Text(
                                      "No payments processed yet.\nClick 'Pay Salary' to log the first payment.",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: Colors.white38,
                                        height: 1.5,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                _buildPaymentList(memberPayments, context),

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
                color: Colors.white.withValues(alpha: 0.05), // White Glass
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
            "Payment History",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Export Button
          GestureDetector(
            onTap: _downloadPaymentHistory,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05), // White Glass
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

  Widget _buildSummaryCard(int paymentCount, double totalPaid) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TOTAL PAID (ALL TIME)",
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(totalPaid),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              letterSpacing: -1,
              fontFeatures: [
                // Enable font features for better symbol support
                const FontFeature.enable('liga'),
                const FontFeature.enable('clig'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  paymentCount == 0
                      ? "No payments yet"
                      : "$paymentCount payment(s) completed",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF30D158),
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

  Widget _buildPaymentList(
    List<Map<String, dynamic>> payments,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("ALL PAYMENTS"),
        const SizedBox(height: 16),
        Column(
          children: payments.map((payment) {
            bool isAdvance = payment['title'] == "Advance Payout";

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  // Navigate to the details screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransactionDetailsScreen(
                        transactionId: payment['id'],
                        transactionData: payment['rawData'],
                        formattedDate: payment['date'],
                        formattedAmount: payment['amt'],
                        displayTitle: payment['title'],
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isAdvance
                                  ? Icons.fast_forward
                                  : Icons.arrow_outward,
                              color: isAdvance
                                  ? const Color(0xFF5E5CE6)
                                  : Colors.white54,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payment['title'],
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                payment['date'],
                                style: GoogleFonts.inter(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            payment['amt'],
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [
                                // Enable font features for better symbol support
                                const FontFeature.enable('liga'),
                                const FontFeature.enable('clig'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF30D158,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              payment['status'],
                              style: GoogleFonts.inter(
                                color: const Color(0xFF30D158),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

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

    return 'Not specified';
  }
}
