import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/bank_account_service.dart';

class TransactionDetailsScreen extends StatefulWidget {
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
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  Map<String, dynamic>? bankAccount;
  bool isLoadingBankAccount = true;

  @override
  void initState() {
    super.initState();
    _fetchBankAccount();
  }

  Future<void> _fetchBankAccount() async {
    try {
      // Check both possible field names for bank account
      final bankAccountId =
          widget.transactionData['bankAccount'] as String? ??
          widget.transactionData['BankAccount'] as String?;

      if (bankAccountId != null && bankAccountId.isNotEmpty) {
        final bankAccounts = await BankAccountService.getBankAccounts();

        final account = bankAccounts.firstWhere(
          (account) => account['id']?.toString() == bankAccountId,
          orElse: () => <String, dynamic>{},
        );
        // T-10: removed incorrect fallback that returned the first
        // company_array_ account found — it was showing the wrong bank
        // for transactions paid from a different account with the same prefix.

        if (account.isNotEmpty) {
          setState(() {
            bankAccount = account;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ DEBUG: Error fetching bank account: $e');
    } finally {
      setState(() {
        isLoadingBankAccount = false;
      });
    }
  }

  String _getBankAccountDisplay() {
    if (isLoadingBankAccount) {
      return 'Loading...';
    }
    if (bankAccount != null && bankAccount!.isNotEmpty) {
      final name = bankAccount!['name'] as String? ?? 'Unknown Bank';
      final last4 = bankAccount!['last4'] as String? ?? '****';
      return '$name ****$last4';
    }

    final bankAccountId =
        widget.transactionData['bankAccount'] as String? ??
        widget.transactionData['BankAccount'] as String?;

    if (bankAccountId != null) {
      // Check if it's a cash transaction (either "Cash-" or "Cash")
      if (bankAccountId == 'Cash-' || bankAccountId == 'Cash') {
        return 'Cash';
      }
      return 'Bank Account ID: $bankAccountId (Not Found)';
    }

    // Check if it's a cash payment
    final paymentMethod = widget.transactionData['PaymentMethod'] as String?;
    if (paymentMethod == 'cash') {
      return 'Cash';
    }

    return 'Not specified';
  }

  @override
  Widget build(BuildContext context) {
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
                      const SizedBox(height: 48),

                      // Clean Big Amount
                      Text(
                        widget.formattedAmount,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1.5,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
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
                            _buildDetailRow(
                              "Transaction Type",
                              widget.displayTitle,
                            ),
                            _buildDivider(),
                            _buildDetailRow(
                              "Date & Time",
                              widget.formattedDate,
                            ),
                            _buildDivider(),
                            // T-11: Read Category from the transaction doc
                            // instead of hardcoding "Salary" for all payments.
                            _buildDetailRow(
                              "Category",
                              widget.transactionData['Category'] as String? ??
                                  widget.transactionData['category']
                                      as String? ??
                                  'Salary',
                            ),
                            _buildDivider(),
                            _buildDetailRow(
                              "Description",
                              widget.transactionData['Title'] ?? 'N/A',
                            ),
                            _buildDivider(),
                            _buildDetailRow(
                              "Payment Method",
                              _getBankAccountDisplay(),
                            ),
                            _buildDivider(),
                            _buildDetailRow(
                              "Transaction ID",
                              widget.transactionId,
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
                color: Colors.white.withValues(alpha: 0.05), // Glassy white
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
              color: Colors.white54, // Better contrast for label
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
                      fontWeight: FontWeight.w600,
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
