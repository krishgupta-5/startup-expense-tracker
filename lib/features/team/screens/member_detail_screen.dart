import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// NOTE: Ensure these files exist or comment them out if testing in isolation
import 'edit_member_screen.dart';
import 'adjust_salary_screen.dart';
import 'payment_history_screen.dart';
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
              final String salary = "\$${cost.toStringAsFixed(2)}";
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

                          // --- PROFILE HERO (Fetching Team Name dynamically) ---
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
                              return _buildProfileHero(
                                name,
                                role,
                                teamName,
                                avatarUrl,
                                status,
                              );
                            },
                          ),

                          const SizedBox(height: 32),

                          // --- FINANCIAL HERO ---
                          _buildCostCard(salary, status),

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

                          // --- RECENT PAYOUTS (AUTOMATED) ---
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
                          _buildPaymentHistory(salary, joinedDateObj),

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

          // More Actions
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
        // Avatar with Ring
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
        // Status Pill
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

  // --- AUTOMATED PAYMENT GENERATOR ---
  Widget _buildPaymentHistory(String currentSalary, DateTime joinedDate) {
    List<Map<String, String>> payments = [];
    final DateTime now = DateTime.now();

    // Start calculating from the 1st of the month AFTER joining
    DateTime paymentDate = DateTime(joinedDate.year, joinedDate.month + 1, 1);

    // Keep adding payments for every 1st of the month until today
    while (paymentDate.isBefore(now) || paymentDate.isAtSameMomentAs(now)) {
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
      final String formattedDate =
          "${months[paymentDate.month - 1]} 01, ${paymentDate.year}";

      payments.add({"date": formattedDate, "amt": currentSalary});

      // Increment by 1 month
      paymentDate = DateTime(paymentDate.year, paymentDate.month + 1, 1);
    }

    // Reverse the list so the newest payments are at the top
    payments = payments.reversed.toList();

    // If they haven't reached their first payout date yet
    if (payments.isEmpty) {
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
            "No payouts processed yet.\nFirst payout will be on the 1st of next month.",
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

    // Limit to displaying the last 3 on this preview screen
    final previewPayments = payments.take(3).toList();

    return Column(
      children: previewPayments.map((p) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
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
                    Text(
                      "Salary Payout",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
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
          ),
        );
      }).toList(),
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

  // --- ACTIONS BOTTOM SHEET ---
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

                // 1. EDIT PROFILE -> Navigates to Edit Screen
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

                // 2. ADJUST SALARY -> Navigates to Salary Screen
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

                // 3. PAUSE / RESUME MEMBER (Firebase Integrated)
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

                // 4. REMOVE MEMBER -> Shows Dialog
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
        color: Colors.transparent, // Ensure hit test works on full width
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

  // --- DELETE CONFIRMATION DIALOG (Firebase Integrated) ---
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
              Navigator.pop(dialogContext); // Close Dialog
              try {
                // Delete from Firebase
                await FirebaseFirestore.instance
                    .collection('members')
                    .doc(widget.memberId)
                    .delete();

                if (context.mounted) {
                  Navigator.pop(context); // Go back to Team List
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
