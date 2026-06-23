import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/currency_formatter.dart';
import '../../../../services/currency_preference_service.dart';

class SalaryHistoryScreen extends StatefulWidget {
  final String memberId;
  final String memberName;
  final double currentSalary;

  const SalaryHistoryScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.currentSalary,
  });

  @override
  State<SalaryHistoryScreen> createState() => _SalaryHistoryScreenState();
}

class _SalaryHistoryScreenState extends State<SalaryHistoryScreen> {
  bool _isRevoking = false;

  // Helper to format currency
  String _formatCurrency(double amount) {
    final userCurrencyCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    return CurrencyFormatter.formatByCountryCompact(amount, userCurrencyCode);
  }

  // Helper to format Firestore Timestamp
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown Date";
    final DateTime dt = timestamp.toDate();
    final List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}";
  }

  void _showMinimalToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? const Color(0xFFFF453A) : const Color(0xFF30D158),
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

  Future<void> _revokeFutureSalary() async {
    setState(() => _isRevoking = true);
    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .update({
            'futureSalary': FieldValue.delete(),
            'futureSalaryDate': FieldValue.delete(),
            'futureSalaryReason': FieldValue.delete(),
          });
      _showMinimalToast("Scheduled update canceled.");
    } catch (e) {
      _showMinimalToast("Failed to cancel update.", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isRevoking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          AnnotatedRegion<SystemUiOverlayStyle>(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32),
                          _buildSectionTitle("PENDING UPDATES"),
                          const SizedBox(height: 16),
                          _buildPendingUpdateSection(),
                          const SizedBox(height: 40),
                          _buildSectionTitle("PAST UPDATES"),
                          const SizedBox(height: 16),
                          _buildHistorySection(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isRevoking)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
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
            "Appraisal History",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 44), // Balances header
        ],
      ),
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
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white12, size: 40),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingUpdateSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final futureSalary = data['futureSalary'];
        final futureDate = data['futureSalaryDate'] as Timestamp?;
        final reason = data['futureSalaryReason'] as String? ?? "No reason provided";

        if (futureSalary == null || futureDate == null) {
          return _buildEmptyState("No upcoming salary updates scheduled.", Icons.schedule_outlined);
        }

        final amountFormatted = _formatCurrency((futureSalary as num).toDouble());
        final currentAmountFormatted = _formatCurrency(widget.currentSalary);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        "EFFECTIVE ${_formatDate(futureDate).toUpperCase()}",
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: _revokeFutureSalary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF453A).withValues(alpha: 0.1),
                        foregroundColor: const Color(0xFFFF453A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: const Color(0xFFFF453A).withValues(alpha: 0.2)),
                        ),
                      ),
                      child: Text(
                        "Cancel Update",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                color: Colors.white.withValues(alpha: 0.04),
                height: 32,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    currentAmountFormatted,
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, color: Colors.white24, size: 16),
                  const SizedBox(width: 12),
                  Text(
                    amountFormatted,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                reason,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistorySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('salary_history')
          .orderBy('changedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("No past salary updates found.", Icons.history_outlined);
        }

        final docs = snapshot.data!.docs;

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final prev = (data['previousSalary'] as num?)?.toDouble() ?? 0.0;
            final current = (data['newSalary'] as num?)?.toDouble() ?? 0.0;
            final delta = (data['delta'] as num?)?.toDouble() ?? (current - prev);
            final reason = data['reason'] as String? ?? 'No reason provided';
            final date = data['effectiveDate'] as Timestamp?;

            bool isIncrease = delta > 0;
            
            // Dynamic colors based on the data
            Color deltaColor = isIncrease ? const Color(0xFF30D158) : const Color(0xFFFF453A);
            String deltaPrefix = isIncrease ? "+" : "";

            // Handle edge case where previous salary was 0 (e.g., initial setup)
            if (prev == 0 && current > 0) {
              deltaColor = Colors.white;
              deltaPrefix = "";
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(date).toUpperCase(),
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: deltaColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: deltaColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          prev == 0 ? "Initial" : "$deltaPrefix${_formatCurrency(delta)}",
                          style: GoogleFonts.inter(
                            color: deltaColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    ],
                  ),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.04),
                    height: 32,
                  ),
                  Row(
                    children: [
                      Text(
                        _formatCurrency(prev),
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 15,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward, color: Colors.white24, size: 16),
                      const SizedBox(width: 12),
                      Text(
                        _formatCurrency(current),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    reason,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}