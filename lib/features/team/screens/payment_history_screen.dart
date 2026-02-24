import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'transaction_details_screen.dart'; // Make sure to import the new screen

class PaymentHistoryScreen extends StatelessWidget {
  final DateTime joiningDate;
  final double salary;
  final String memberName;

  const PaymentHistoryScreen({
    super.key,
    required this.joiningDate,
    required this.salary,
    required this.memberName,
  });

  // Helper to format currency
  String _formatCurrency(double amount) {
    return "₹${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";
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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      body: AnnotatedRegion<SystemUiOverlayStyle>(
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

                      // Filter: Must be a salary expense AND contain the member's name
                      if (category == 'salary' && title.contains(memberName)) {
                        final double amt = data['Amount'] is int
                            ? (data['Amount'] as int).toDouble()
                            : (data['Amount'] as double? ?? 0.0);

                        totalPaid += amt;
                        memberPayments.add({
                          "id": doc.id, // Store doc ID for the details page
                          "rawData": data, // Store raw map for the details page
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
                        children: [
                          const SizedBox(height: 32),

                          // --- SUMMARY CARD ---
                          _buildSummaryCard(memberPayments.length, totalPaid),

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
                            _buildPaymentList(
                              memberPayments,
                              context,
                            ), // Passed context here

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
            "Payment History",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Export Button
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF141416),
                  content: Text(
                    "Export feature coming soon",
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              );
            },
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
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
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
        title,
        style: GoogleFonts.inter(
          color: Colors.white24,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
