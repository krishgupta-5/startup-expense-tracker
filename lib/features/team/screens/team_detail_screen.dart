import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'edit_team_screen.dart';
import 'add_member_screen.dart';
// NOTE: Make sure member_detail_screen exists or comment out the navigation to it
import 'member_detail_screen.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/user_country_service.dart';

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
  String _userCountryCode = '+1'; // Default to USD

  // Cache for Telegram photos to avoid repeated fetching
  static final Map<String, String> _telegramPhotoCache = {};

  @override
  void initState() {
    super.initState();
    // Get country code synchronously for instant display
    _userCountryCode = UserCountryService.getUserCountryCodeSync();
    // Load in background for more accurate result
    _loadUserCountryCode();
  }

  Future<void> _loadUserCountryCode() async {
    final countryCode = await UserCountryService.getUserCountryCode();
    if (mounted && countryCode != _userCountryCode) {
      setState(() {
        _userCountryCode = countryCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      // --- THEMED FAB ---
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Matches the 'New Team' FAB
        ),
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          "Add Member",
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),

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
                return Center(
                  child: Text(
                    "Error loading team",
                    style: GoogleFonts.inter(color: Colors.white54),
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
                              strokeWidth: 2,
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
                              const SizedBox(height: 16),

                              // --- HERO STATS ---
                              _buildHeroStats(totalCost, isWithinBudget),

                              const SizedBox(height: 32),

                              // --- MEMBERS LIST HEADER ---
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSectionTitle(
                                    "TEAM MEMBERS ($memberCount)",
                                  ),
                                  _buildSectionTitle("SORT BY COST"),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // --- MEMBERS LIST ---
                              if (sortedMembers.isEmpty)
                                _buildEmptyState("No members in this team yet.")
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

                              const SizedBox(height: 100), // Padding for FAB
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
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context, String teamName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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

          Expanded(
            child: Text(
              teamName,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: Colors.white24,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildHeroStats(double totalCost, bool isWithinBudget) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20), // Matched to TeamCard radius
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Text(
            "TOTAL MONTHLY COST",
            style: GoogleFonts.inter(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.formatByCountry(totalCost, _userCountryCode),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w600,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isWithinBudget
                  ? const Color(0xFF0A84FF).withValues(alpha: 0.1)
                  : const Color(0xFFFF453A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isWithinBudget
                    ? const Color(0xFF0A84FF).withValues(alpha: 0.2)
                    : const Color(0xFFFF453A).withValues(alpha: 0.2),
              ),
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
    final String salary =
        "${CurrencyFormatter.formatByCountry(rawCost, _userCountryCode)}/mo";

    // Default status to Active if it doesn't exist
    final String status = member['status'] ?? 'Active';
    final bool isPaused = status == 'Paused';

    // Check for Telegram photo first, then regular avatar
    final String? telegramFileId = member['telegramFileId'];
    final String? avatarUrl = member['avatarUrl'];

    // Determine if avatarUrl contains a Telegram file ID (for backward compatibility)
    final String? telegramFileIdFromAvatar =
        (avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            !avatarUrl.startsWith('http') &&
            !avatarUrl.contains('ui-avatars.com'))
        ? avatarUrl
        : null;

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
          padding: const EdgeInsets.all(20), // Matched padding to TeamCard
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
                  _buildMemberAvatar(
                    name,
                    48,
                    avatarUrl ?? "",
                    telegramFileId ?? telegramFileIdFromAvatar,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isPaused
                            ? const Color(0xFFFF9F0A)
                            : const Color(0xFF30D158),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF141416),
                          width: 2.5,
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
                        fontSize: 16, // Matched size to TeamCard title
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
                  GestureDetector(
                    onTap: () =>
                        _showMemberOptions(context, memberId, name, isPaused),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      color: Colors.transparent, // Expands hit area
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white24,
                        size: 20,
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
  }

  // --- EMPTY STATE (UPDATED: No Icon, Perfectly Centered on Full Screen) ---
  Widget _buildEmptyState(String message) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: const Center(
        child: Text(
          "No members in the team yet",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 14,
            fontWeight: FontWeight.w500,
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

  // Build member avatar with Telegram photo support
  Widget _buildMemberAvatar(
    String name,
    double size,
    String avatarUrl,
    String? telegramFileId,
  ) {
    // Check if it's a Telegram photo
    if (telegramFileId != null && telegramFileId.isNotEmpty) {
      return FutureBuilder<String>(
        future: getTelegramImageUrl(telegramFileId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show loading indicator while fetching Telegram photo
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.3,
                  height: size * 0.3,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white38,
                  ),
                ),
              ),
            );
          } else if (snapshot.hasError || !snapshot.hasData) {
            // Fallback to generated avatar on error
            return AvatarWidget(
              name: name,
              size: size,
              imageUrl: null,
              fontSize: size * 0.4,
            );
          } else {
            // Show Telegram photo
            return AvatarWidget(
              name: name,
              size: size,
              imageUrl: snapshot.data!,
              fontSize: size * 0.4,
            );
          }
        },
      );
    } else {
      // Handle regular avatar URL
      return AvatarWidget(
        name: name,
        size: size,
        imageUrl: avatarUrl.isNotEmpty && !avatarUrl.contains('ui-avatars.com')
            ? avatarUrl
            : null,
        fontSize: size * 0.4,
      );
    }
  }

  // Telegram photo fetching methods with caching
  Future<String> getTelegramImageUrl(String fileId) async {
    // Check cache first
    if (_telegramPhotoCache.containsKey(fileId)) {
      return _telegramPhotoCache[fileId]!;
    }

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
      final imageUrl = "https://api.telegram.org/file/bot$botToken/$path";

      // Cache the result
      _telegramPhotoCache[fileId] = imageUrl;

      return imageUrl;
    } catch (e) {
      debugPrint('Error getting Telegram image URL: $e');
      rethrow;
    }
  }
}
