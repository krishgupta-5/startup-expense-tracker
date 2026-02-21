import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'edit_team_screen.dart';
import 'add_member_screen.dart';
// NOTE: Make sure member_detail_screen exists or comment out the navigation to it
import 'member_detail_screen.dart';
import '../../../widgets/avatar_widget.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamId;
  final Map<String, dynamic> initialTeamData;

  const TeamDetailScreen({
    super.key,
    required this.teamId,
    required this.initialTeamData,
  });

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
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
                .collection('teams')
                .doc(widget.teamId)
                .snapshots(),
            builder: (context, teamSnapshot) {
              if (teamSnapshot.hasError) {
                return const Center(
                  child: Text(
                    "Error loading team",
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              // Use latest team data, fallback to initial if loading
              final teamData =
                  teamSnapshot.hasData && teamSnapshot.data!.data() != null
                  ? teamSnapshot.data!.data() as Map<String, dynamic>
                  : widget.initialTeamData;

              final String teamName = teamData['teamName'] ?? "Team";
              final double teamBudget =
                  (teamData['monthlyBudget'] ?? 0.0) as double;

              return Column(
                children: [
                  // 1. Header (Now uses real-time data)
                  _buildHeader(context, teamName),

                  // 2. Real-time Content (Stream for Members Data)
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('members')
                          .where('teamId', isEqualTo: widget.teamId)
                          .snapshots(),
                      builder: (context, membersSnapshot) {
                        if (membersSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !membersSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white38,
                            ),
                          );
                        }

                        final membersDocs = membersSnapshot.data?.docs ?? [];

                        // Calculate stats
                        double totalCost = 0.0;
                        for (var doc in membersDocs) {
                          final data = doc.data() as Map<String, dynamic>;
                          totalCost += (data['monthlyCost'] ?? 0.0) as double;
                        }

                        final bool isWithinBudget = totalCost <= teamBudget;
                        final String memberCount =
                            "${membersDocs.length} Members";

                        // Sort members by cost (Highest to lowest)
                        final sortedMembers = membersDocs.toList();
                        sortedMembers.sort((a, b) {
                          final costA =
                              ((a.data()
                                          as Map<
                                            String,
                                            dynamic
                                          >)['monthlyCost'] ??
                                      0.0)
                                  as double;
                          final costB =
                              ((b.data()
                                          as Map<
                                            String,
                                            dynamic
                                          >)['monthlyCost'] ??
                                      0.0)
                                  as double;
                          return costB.compareTo(costA);
                        });

                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),

                              // --- HERO STATS ---
                              _buildHeroStats(totalCost, isWithinBudget),

                              const SizedBox(height: 32),

                              // --- MEMBERS LIST HEADER ---
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "TEAM MEMBERS ($memberCount)",
                                    style: GoogleFonts.inter(
                                      color: Colors.white24,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  Text(
                                    "SORT BY COST",
                                    style: GoogleFonts.inter(
                                      color: Colors.white24,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // --- MEMBERS LIST ---
                              if (sortedMembers.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 32),
                                  child: Center(
                                    child: Text(
                                      "No members in this team yet.",
                                      style: GoogleFonts.inter(
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: sortedMembers.length,
                                  itemBuilder: (context, index) {
                                    return _buildMemberRow(
                                      sortedMembers[index],
                                    );
                                  },
                                ),

                              const SizedBox(height: 80),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMemberScreen()),
          );
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(
          "Add Member",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context, String teamName) {
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
            teamName,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Settings / Edit Team
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTeamScreen(
                    teamId: widget.teamId,
                    teamData: widget.initialTeamData,
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
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStats(double totalCost, bool isWithinBudget) {
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
            "TOTAL MONTHLY COST",
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "\$${totalCost.toStringAsFixed(2)}",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w600,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isWithinBudget
                  ? const Color(0xFF0A84FF).withValues(alpha: 0.15)
                  : const Color(0xFFFF453A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isWithinBudget ? "Within Budget" : "Over Budget",
              style: GoogleFonts.inter(
                color: isWithinBudget
                    ? const Color(0xFF0A84FF)
                    : const Color(0xFFFF453A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(QueryDocumentSnapshot doc) {
    final member = doc.data() as Map<String, dynamic>;
    final memberId = doc.id;

    final String name = member['fullName'] ?? 'Unnamed Member';
    final String role = member['jobTitle'] ?? 'No Role';
    final double rawCost = (member['monthlyCost'] ?? 0.0) as double;
    final String salary = "\$${rawCost.toStringAsFixed(0)}/mo";

    // Default status to Active if it doesn't exist
    final String status = member['status'] ?? 'Active';
    final bool isPaused = status == 'Paused';

    // Generate an automatic avatar from initials since we skipped image upload
    final String avatarUrl =
        member['avatarUrl'] ??
        "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=random&color=fff";

    return GestureDetector(
      onTap: () {
        // Navigate to member details
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemberDetailScreen(memberId: memberId),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  AvatarWidget(
                    name: name,
                    size: 48,
                    imageUrl:
                        avatarUrl.isNotEmpty &&
                            avatarUrl.contains('ui-avatars.com')
                        ? null
                        : avatarUrl,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isPaused
                            ? const Color(0xFFFF9F0A)
                            : const Color(0xFF30D158),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF141416),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: isPaused
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role,
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Cost & Menu
              Row(
                children: [
                  Text(
                    salary,
                    style: GoogleFonts.inter(
                      color: isPaused ? Colors.white38 : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white24,
                      size: 20,
                    ),
                    onPressed: () =>
                        _showMemberOptions(context, memberId, name, isPaused),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ACTIONS BOTTOM SHEET (FIREBASE ENABLED) ---
  void _showMemberOptions(
    BuildContext context,
    String memberId,
    String memberName,
    bool isCurrentlyPaused,
  ) {
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),

                // Pause / Resume Logic
                _buildActionOption(
                  isCurrentlyPaused
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                  isCurrentlyPaused ? "Resume Member" : "Pause Member",
                  () async {
                    Navigator.pop(bottomSheetContext);
                    try {
                      await FirebaseFirestore.instance
                          .collection('members')
                          .doc(memberId)
                          .update({
                            'status': isCurrentlyPaused ? 'Active' : 'Paused',
                          });
                    } catch (e) {
                      debugPrint("Error updating status: $e");
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Remove Logic
                _buildActionOption(
                  Icons.person_remove_outlined,
                  "Remove from Team",
                  () async {
                    Navigator.pop(bottomSheetContext);
                    try {
                      await FirebaseFirestore.instance
                          .collection('members')
                          .doc(memberId)
                          .delete();
                    } catch (e) {
                      debugPrint("Error deleting member: $e");
                    }
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
        padding: const EdgeInsets.symmetric(vertical: 12),
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
}
