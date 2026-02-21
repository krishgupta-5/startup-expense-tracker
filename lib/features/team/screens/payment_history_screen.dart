import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentHistoryScreen extends StatelessWidget {
  final DateTime joiningDate;
  final double salary;

  const PaymentHistoryScreen({
    super.key,
    required this.joiningDate,
    required this.salary,
  });

  // Helper to format currency
  String _formatCurrency(double amount) {
    return "\$${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";
  }

  // Generate dynamic payment history
  List<Map<String, String>> _generatePaymentHistory() {
    List<Map<String, String>> payments = [];
    final DateTime now = DateTime.now();

    // Start calculating from the 1st of the month AFTER joining
    DateTime paymentDate = DateTime(joiningDate.year, joiningDate.month + 1, 1);
    final String formattedSalary = _formatCurrency(salary);

    final List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    while (paymentDate.isBefore(now) || paymentDate.isAtSameMomentAs(now)) {
      final String formattedDate = "${months[paymentDate.month - 1]} 01, ${paymentDate.year}";

      payments.add({
        "date": formattedDate,
        "amt": formattedSalary,
        "status": "Completed",
      });

      // Increment by 1 month
      paymentDate = DateTime(paymentDate.year, paymentDate.month + 1, 1);
    }

    // Reverse so the newest payments are at the top
    return payments.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final payments = _generatePaymentHistory();

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

              // 2. Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // --- SUMMARY CARD ---
                      _buildSummaryCard(payments),

                      const SizedBox(height: 32),

                      // --- PAYMENT LIST ---
                      if (payments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              "No payments processed yet.\nFirst payout will be on the 1st of next month.",
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
                        _buildPaymentList(payments),

                      const SizedBox(height: 40),
                    ],
                  ),
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

  Widget _buildSummaryCard(List<Map<String, String>> payments) {
    // Calculate total based on generated history
    final double totalPaid = payments.length * salary;

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
                  payments.isEmpty ? "No payments yet" : "All payments completed",
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

  Widget _buildPaymentList(List<Map<String, String>> payments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("ALL PAYMENTS"),
        const SizedBox(height: 16),
        Column(
          children: payments.map((payment) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                          child: const Icon(
                            Icons.arrow_outward,
                            color: Colors.white54,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Salary Payout",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              payment['date']!,
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
                          payment['amt']!,
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
                            payment['status']!,
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