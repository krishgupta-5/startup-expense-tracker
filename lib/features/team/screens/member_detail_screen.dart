import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// NOTE: Ensure these files exist or comment them out if testing in isolation
import 'edit_member_screen.dart';
import 'adjust_salary_screen.dart';
import 'payment_history_screen.dart';
import 'process_payment_screen.dart';
import 'transaction_details_screen.dart'; // <-- IMPORTED NEW SCREEN
import '../../../widgets/avatar_widget.dart';

class MemberDetailScreen extends StatefulWidget {
  final String memberId;

  const MemberDetailScreen({super.key, required this.memberId});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  // Format the raw employment type to a readable string
  String _formatEmploymentType(String raw) {
    switch (raw) {
      case 'full_time':
        return 'Full-time';
      case 'part_time':
        return 'Part-time';
      case 'contractor':
        return 'Contractor';
      case 'intern':
        return 'Intern';
      default:
        return raw;
    }
  }

  // Format Timestamp to "Aug 12, 2023" format
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown";
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
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('members')
                .doc(widget.memberId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white38),
                );
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  !snapshot.data!.exists) {
                return const Center(
                  child: Text(
                    "Member not found.",
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              final memberData = snapshot.data!.data() as Map<String, dynamic>;

              final String name = memberData['fullName'] ?? "Unnamed Member";
              final String role = memberData['jobTitle'] ?? "No Role";
              final String email = memberData['email'] ?? "No Email";
              final String status = memberData['status'] ?? "Active";
              final double cost = (memberData['monthlyCost'] ?? 0.0) as double;
              final String salary = "₹${cost.toStringAsFixed(2)}";
              final String empType = _formatEmploymentType(
                memberData['employmentType'] ?? "",
              );

              // Get Joining Date
              final Timestamp? joinedTs =
                  memberData['joiningDate'] as Timestamp?;
              final DateTime joinedDateObj =
                  joinedTs?.toDate() ?? DateTime.now();
              final String joinedDateStr = _formatDate(joinedTs);

              final String teamId = memberData['teamId'] ?? "";

              // Generate dynamic avatar
              final String avatarUrl =
                  memberData['avatarUrl'] ??
                  "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff";

              return Column(
                children: [
                  // 1. Header
                  _buildHeader(context, name, status, cost, memberData),

                  // 2. Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),

                          // --- PROFILE HERO ---
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('teams')
                                .doc(teamId)
                                .get(),
                            builder: (context, teamSnapshot) {
                              String teamName = "Loading Team...";
                              if (teamSnapshot.hasData &&
                                  teamSnapshot.data!.exists) {
                                teamName =
                                    (teamSnapshot.data!.data()
                                        as Map<String, dynamic>)['teamName'] ??
                                    "Unknown Team";
                              }

                              return Column(
                                children: [
                                  _buildProfileHero(
                                    name,
                                    role,
                                    teamName,
                                    avatarUrl,
                                    status,
                                  ),

                                  const SizedBox(height: 32),

                                  // --- FINANCIAL HERO ---
                                  _buildCostCard(salary, status),

                                  const SizedBox(height: 16),

                                  // --- PAY SALARY / ADVANCE ACTION ---
                                  _buildPaySalaryAction(
                                    cost,
                                    joinedDateObj,
                                    status,
                                    name,
                                    teamName,
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 32),

                          // --- DETAILS SECTION ---
                          _buildSectionTitle("EMPLOYMENT DETAILS"),
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
                                _buildDetailRow(
                                  "Email",
                                  email,
                                  Icons.email_outlined,
                                ),
                                _buildDivider(),
                                _buildDetailRow(
                                  "Joined",
                                  joinedDateStr,
                                  Icons.calendar_today,
                                ),
                                _buildDivider(),
                                _buildDetailRow(
                                  "Type",
                                  empType,
                                  Icons.badge_outlined,
                                ),
                                _buildDivider(),
                                _buildDetailRow(
                                  "Location",
                                  "Remote",
                                  Icons.location_on_outlined,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // --- RECENT PAYOUTS ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle("PAYMENT HISTORY"),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          PaymentHistoryScreen(
                                            joiningDate: joinedDateObj,
                                            salary: cost,
                                            memberName: name,
                                          ),
                                    ),
                                  );
                                },
                                child: Text(
                                  "VIEW ALL",
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF0A84FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildPaymentHistory(salary, joinedDateObj, name),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(
    BuildContext context,
    String memberName,
    String currentStatus,
    double currentSalary,
    Map<String, dynamic> memberData,
  ) {
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
            "Member Profile",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          GestureDetector(
            onTap: () => _showMemberActionSheet(
              context,
              memberName,
              currentStatus,
              currentSalary,
              memberData,
            ),
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

  Widget _buildProfileHero(
    String name,
    String role,
    String team,
    String avatarUrl,
    String status,
  ) {
    Color statusColor = status == "Active"
        ? const Color(0xFF30D158)
        : const Color(0xFFFF9F0A);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
            ),
            AvatarWidget(
              name: name,
              size: 100,
              imageUrl:
                  avatarUrl.isNotEmpty && avatarUrl.contains('ui-avatars.com')
                  ? null
                  : avatarUrl,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "$role • $team",
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
          ),
          child: Text(
            status.toUpperCase(),
            style: GoogleFonts.inter(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCostCard(String salary, String status) {
    bool isPaused = status == "Paused";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Text(
            "MONTHLY COST",
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPaused ? "\$0.00" : salary,
            style: GoogleFonts.inter(
              color: isPaused ? Colors.white38 : Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w600,
              letterSpacing: -1,
              decoration: isPaused ? TextDecoration.lineThrough : null,
              decorationColor: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPaused ? Icons.pause_circle_outline : Icons.trending_flat,
                color: isPaused ? const Color(0xFFFF9F0A) : Colors.white38,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isPaused ? "Payroll Suspended" : "No change from last month",
                style: GoogleFonts.inter(
                  color: isPaused ? const Color(0xFFFF9F0A) : Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaySalaryAction(
    double cost,
    DateTime joinedDate,
    String status,
    String memberName,
    String teamName,
  ) {
    bool isPaused = status == "Paused";

    // Hide payment option if payroll is suspended
    if (isPaused) return const SizedBox.shrink();

    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    int joinDay = joinedDate.day;

    DateTime nextDueDate = DateTime(now.year, now.month, joinDay);

    // If we are more than 10 days past this month's due date,
    // assume the current cycle is paid and look forward to next month's due date.
    if (today.difference(nextDueDate).inDays > 10) {
      nextDueDate = DateTime(now.year, now.month + 1, joinDay);
    }

    // Ensure the due date is at least 1 full month after their join date
    DateTime firstDue = DateTime(
      joinedDate.year,
      joinedDate.month + 1,
      joinDay,
    );
    if (nextDueDate.isBefore(firstDue)) {
      nextDueDate = firstDue;
    }

    // If today is strictly before the due date, it's an advance.
    bool isAdvance = today.isBefore(nextDueDate);

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
    String formattedDueDate =
        "${months[nextDueDate.month - 1]} ${nextDueDate.day}, ${nextDueDate.year}";

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Colors.white38, size: 14),
            const SizedBox(width: 6),
            Text(
              "Next Due: $formattedDueDate",
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProcessPaymentScreen(
                    memberId: widget.memberId,
                    memberName: memberName,
                    teamName: teamName,
                    defaultAmount: cost,
                    isAdvance: isAdvance,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAdvance
                  ? const Color(0xFF5E5CE6)
                  : const Color(0xFF0A84FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              isAdvance ? "ADVANCE PAY" : "PAY SALARY",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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

  Widget _buildPaymentHistory(
    String currentSalary,
    DateTime joinedDate,
    String memberName,
  ) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white38),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Center(
              child: Text(
                "Error loading payment history.",
                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          );
        }

        // Extract and filter data for this member
        final allDocs = snapshot.data?.docs ?? [];
        List<Map<String, dynamic>> memberPayments = [];

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

            // Capture raw data and ID for the details screen
            memberPayments.add({
              "id": doc.id,
              "rawData": data,
              "rawDate": data['Date'] as Timestamp?,
              "date": _formatDate(data['Date'] as Timestamp?),
              "amt": "₹${amt.toStringAsFixed(2)}",
              "title": title.contains("Advance")
                  ? "Advance Payout"
                  : "Salary Payout",
            });
          }
        }

        // Sort newest first and take only top 3
        memberPayments.sort((a, b) {
          final Timestamp? dateA = a["rawDate"];
          final Timestamp? dateB = b["rawDate"];
          if (dateA == null || dateB == null) return 0;
          return dateB.compareTo(dateA);
        });

        final previewPayments = memberPayments.take(3).toList();

        if (previewPayments.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Center(
              child: Text(
                "No payouts processed yet.\nClick 'Pay Salary' to log the first payment.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }

        return Column(
          children: previewPayments.map((p) {
            bool isAdvance = p['title'] == "Advance Payout";

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              // --- ADDED GESTURE DETECTOR HERE ---
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransactionDetailsScreen(
                        transactionId: p['id'],
                        transactionData: p['rawData'],
                        formattedDate: p['date'],
                        formattedAmount: p['amt'],
                        displayTitle: p['title'],
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
                                p['title']!,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p['date']!,
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
                            p['amt']!,
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
                              "Completed",
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
        );
      },
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

  void _showMemberActionSheet(
    BuildContext context,
    String memberName,
    String currentStatus,
    double currentSalary,
    Map<String, dynamic> memberData,
  ) {
    bool isPaused = currentStatus == "Paused";

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Manage $memberName",
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 24),

                _buildActionOption(Icons.edit_outlined, "Edit Profile", () {
                  Navigator.pop(bottomSheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditMemberScreen(
                        memberId: widget.memberId,
                        memberData: memberData,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                _buildActionOption(Icons.attach_money, "Adjust Salary", () {
                  Navigator.pop(bottomSheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdjustSalaryScreen(
                        memberId: widget.memberId,
                        currentSalary: currentSalary,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                _buildActionOption(
                  isPaused
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                  isPaused ? "Resume Member" : "Pause Member",
                  () async {
                    Navigator.pop(bottomSheetContext);
                    try {
                      await FirebaseFirestore.instance
                          .collection('members')
                          .doc(widget.memberId)
                          .update({'status': isPaused ? 'Active' : 'Paused'});

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF141416),
                            content: Text(
                              isPaused
                                  ? "Member resumed."
                                  : "Member paused. Payroll suspended.",
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint("Failed to update status: $e");
                    }
                  },
                ),

                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),

                _buildActionOption(
                  Icons.person_remove_outlined,
                  "Remove Member",
                  () {
                    Navigator.pop(bottomSheetContext);
                    _showDeleteConfirmation(context, memberName);
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionOption(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.transparent,
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

  void _showDeleteConfirmation(BuildContext context, String memberName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF141416),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Remove Member?",
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          "This will remove $memberName from the team and archive all payment history.",
          style: GoogleFonts.inter(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              "CANCEL",
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirebaseFirestore.instance
                    .collection('members')
                    .doc(widget.memberId)
                    .delete();

                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                debugPrint("Failed to delete member: $e");
              }
            },
            child: Text(
              "REMOVE",
              style: GoogleFonts.inter(color: const Color(0xFFFF453A)),
            ),
          ),
        ],
      ),
    );
  }
}
