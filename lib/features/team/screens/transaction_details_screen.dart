import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final String transactionId;
  final Map<String, dynamic> transactionData;
  final String formattedDate;
  final String formattedAmount;
  final String displayTitle;

  const TransactionDetailsScreen({
    super.key,
    required this.transactionId,
    required this.transactionData,
    required this.formattedDate,
    required this.formattedAmount,
    required this.displayTitle,
  });

  @override
  Widget build(BuildContext context) {
    bool isAdvance = displayTitle == "Advance Payout";

    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Icon Avatar
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Icon(
                          isAdvance ? Icons.fast_forward : Icons.check_circle,
                          color: isAdvance
                              ? const Color(0xFF5E5CE6)
                              : const Color(0xFF30D158),
                          size: 32,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Big Amount
                      Text(
                        formattedAmount,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF30D158).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Completed",
                          style: GoogleFonts.inter(
                            color: const Color(0xFF30D158),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Details Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow("Transaction Type", displayTitle),
                            _buildDivider(),
                            _buildDetailRow("Date & Time", formattedDate),
                            _buildDivider(),
                            _buildDetailRow("Category", "Salary"),
                            _buildDivider(),
                            _buildDetailRow(
                              "Description",
                              transactionData['Title'] ?? 'N/A',
                            ),
                            _buildDivider(),
                            _buildDetailRow(
                              "Transaction ID",
                              transactionId,
                              isId: true,
                            ),
                          ],
                        ),
                      ),

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
            "Transaction Details",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(
            width: 44,
          ), // To balance the back button and center the title
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isId = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: isId
                  ? GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    )
                  : GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(color: Colors.white.withValues(alpha: 0.04), height: 1),
    );
  }
}
