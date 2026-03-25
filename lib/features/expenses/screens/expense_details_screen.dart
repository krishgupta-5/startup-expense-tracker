import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'edit_expense_screen.dart';

class ExpenseDetailsScreen extends StatefulWidget {
  final String expenseId;
  final Map<String, dynamic> expenseData;

  const ExpenseDetailsScreen({
    super.key,
    required this.expenseId,
    required this.expenseData,
  });

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  double safeParse(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('expenses')
          .doc(widget.expenseId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF09090B),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF09090B),
            body: Center(
              child: Text(
                'Error loading expense details',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFF09090B),
            body: Center(
              child: Text(
                'Expense not found',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          );
        }

        final updatedExpenseData =
            snapshot.data!.data() as Map<String, dynamic>;
        return _buildExpenseDetails(context, updatedExpenseData);
      },
    );
  }

  Widget _buildExpenseDetails(
    BuildContext context,
    Map<String, dynamic> expenseData,
  ) {
    // Safely extract data from Firebase
    final title = expenseData['Title'] ?? 'Unnamed Expense';
    final amount = safeParse(expenseData['Amount']);
    final rawCategory = expenseData['Category']?.toString() ?? 'General';
    final category = rawCategory.toUpperCase();
    final rawType = expenseData['Type']?.toString() ?? 'one_time';
    final type = _formatType(rawType);
    final notes = expenseData['Description'] ?? 'No notes provided.';

    // Format Date and Time
    String dateStr = 'Unknown Date';
    String timeStr = '--:--';
    if (expenseData['Date'] is Timestamp) {
      final DateTime date = (expenseData['Date'] as Timestamp).toDate();
      dateStr = "${date.day}/${date.month}/${date.year}";
    }
    if (expenseData['Time'] is Timestamp) {
      final DateTime time = (expenseData['Time'] as Timestamp).toDate();
      // Simple 24h time formatting
      timeStr =
          "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Header with Actions
              _buildHeader(context),

              // 2. Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),

                      // Hero Amount & Title
                      Center(
                        child: Column(
                          children: [
                            _buildCategoryBadge(category),
                            const SizedBox(height: 24),
                            Text(
                              "₹${amount.toStringAsFixed(2)}",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // --- DETAILS SECTION ---
                      _buildSectionTitle("DETAILS"),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow("Date", dateStr),
                            _buildDivider(),
                            _buildDetailRow("Time", timeStr),
                            _buildDivider(),
                            _buildDetailRow("Type", type),
                            _buildDivider(),
                            // Placeholder for linked member since we haven't added users yet
                            _buildTeamRow(
                              "Linked Member",
                              "https://i.pravatar.cc/150?img=68",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Notes
                      _buildSectionTitle("NOTES"),
                      const SizedBox(height: 12),
                      Text(
                        notes,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Attachment (Placeholder for now)
                      _buildSectionTitle("ATTACHMENT"),
                      const SizedBox(height: 12),
                      _buildAttachmentPreview(expenseData),

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

  // Helper method to format types like 'one_time' to 'One Time'
  String _formatType(String raw) {
    return raw
        .split('_')
        .map((word) {
          if (word.isEmpty) return '';
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  // Method to duplicate expense
  Future<void> _duplicateExpense(
    BuildContext context,
    Map<String, dynamic> expenseData,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("User not logged in", style: GoogleFonts.inter()),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final id = const Uuid().v4();

      await FirebaseFirestore.instance.collection('expenses').doc(id).set({
        "uid": user.uid,
        "Amount": expenseData['Amount'] ?? 0.0,
        "Title": "${expenseData['Title'] ?? 'Expense'} (Copy)",
        "Description": expenseData['Description'] ?? '',
        "Date": DateTime.now(),
        "Category": expenseData['Category'] ?? 'general',
        "Type": expenseData['Type'] ?? 'one_time',
        "Time": FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Expense duplicated successfully",
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF30D158),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to duplicate expense",
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // --- WIDGET BUILDERS ---

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
            "Details",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Actions Menu Button
          GestureDetector(
            onTap: () => _showOptionsBottomSheet(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: const Icon(
                Icons.more_horiz,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pie_chart_outline, color: Colors.white54, size: 14),
          const SizedBox(width: 6),
          Text(
            category,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: Colors.white24,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamRow(String label, String imageUrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(color: Colors.white.withValues(alpha: 0.04), height: 1),
    );
  }

  Future<String> getTelegramImageUrl(String fileId) async {
    try {
      await dotenv.load(fileName: ".env.local");
      final botToken = dotenv.env['TELEGRAM_BOT_TOKEN'];

      if (botToken == null) {
        throw Exception('Telegram bot token not found in environment');
      }

      final res = await http.get(
        Uri.parse(
          "https://api.telegram.org/bot$botToken/getFile?file_id=$fileId",
        ),
      );

      final data = jsonDecode(res.body);
      final path = data['result']['file_path'];

      return "https://api.telegram.org/file/bot$botToken/$path";
    } catch (e) {
      debugPrint('Error getting Telegram image URL: $e');
      rethrow;
    }
  }

  Widget _buildAttachmentPreview(Map<String, dynamic> expenseData) {
    final attachmentFileId = expenseData['AttachmentFileId'] as String?;

    if (attachmentFileId == null || attachmentFileId.isEmpty) {
      // No attachment
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.description,
                color: Colors.white54,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "No receipt attached",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "0 KB",
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Has attachment - show image preview
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF30D158).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt,
                  color: Color(0xFF30D158),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Receipt attached",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF30D158),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "Stored in Telegram",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Show image preview
          FutureBuilder<String>(
            future: getTelegramImageUrl(attachmentFileId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF30D158),
                    strokeWidth: 2,
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      "Failed to load image",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  snapshot.data!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          "Failed to load image",
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- ACTIONS BOTTOM SHEET ---
  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 32),
                _buildActionOption(
                  icon: Icons.edit_outlined,
                  label: "Edit Expense",
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditExpenseScreen(
                          expenseId: widget.expenseId,
                          expenseData: widget.expenseData,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildActionOption(
                  icon: Icons.copy_rounded,
                  label: "Duplicate",
                  onTap: () {
                    _duplicateExpense(context, widget.expenseData);
                  },
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white10, height: 32),
                _buildActionOption(
                  icon: Icons.delete_outline_rounded,
                  label: "Delete Expense",
                  isDestructive: true,
                  onTap: () async {
                    Navigator.pop(
                      bottomSheetContext,
                    ); // Close sheet immediately

                    // --- FIREBASE DELETE LOGIC ---
                    try {
                      // Get the expense amount before deleting
                      final expenseAmount = widget.expenseData['Amount'] ?? 0.0;

                      await FirebaseFirestore.instance
                          .collection('expenses')
                          .doc(widget.expenseId)
                          .delete();

                      // Update totalExpenses by subtracting the deleted expense amount
                      await _updateTotalExpensesAfterDeletion(expenseAmount);

                      if (context.mounted) {
                        Navigator.pop(context); // Go back to the list screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Expense deleted",
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: Colors.black,
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint("Failed to delete expense: $e");
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateTotalExpensesAfterDeletion(double expenseAmount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get current company data
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(user.uid)
          .get();

      if (companyDoc.exists && companyDoc.data() != null) {
        final data = companyDoc.data()!;
        final currentTotalExpenses =
            double.tryParse(data["totalExpenses"]?.toString() ?? "0") ?? 0.0;

        // Calculate new total expenses (subtract the deleted expense)
        final newTotalExpenses = currentTotalExpenses - expenseAmount;

        // Update the totalExpenses field
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(user.uid)
            .update({"totalExpenses": newTotalExpenses.toString()});

        log(
          "DEBUG: Updated totalExpenses from $currentTotalExpenses to $newTotalExpenses after deletion",
        );
      }
    } catch (e) {
      log("DEBUG: Error updating totalExpenses after deletion: $e");
    }
  }

  Widget _buildActionOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? const Color(0xFFFF453A) : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isDestructive ? const Color(0xFFFF453A) : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
