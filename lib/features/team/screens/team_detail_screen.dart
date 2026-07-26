import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'edit_team_screen.dart';
import 'add_member_screen.dart';
import 'member_detail_screen.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/currency_preference_service.dart';
import '../../../services/telegram_service.dart';
import 'team_expense_history_screen.dart';
import '../../../utils/expense_expansion_helper.dart';
import '../../../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
    _loadUserCountryCode();
  }

  @override
  void dispose() {
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    super.dispose();
  }

  void _onCurrencyChanged() {
    if (mounted) {
      setState(() {
        _userCountryCode =
            CurrencyPreferenceService.getCurrencyPreferenceSync();
      });
    }
  }

  Future<void> _loadUserCountryCode() async {
    final currencyCode =
        await CurrencyPreferenceService.getCurrencyPreference();
    if (mounted && currencyCode != _userCountryCode) {
      setState(() {
        _userCountryCode = currencyCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,

      // --- THEMED FAB ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMemberScreen(teamId: widget.teamId),
            ),
          );
        },
        backgroundColor: context.textPrimary,
        foregroundColor: context.appBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          "Add Member",
          style: TextStyle(
            fontFamily: 'Satoshi',
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: context.isDarkMode
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
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
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      color: context.textSecondary,
                    ),
                  ),
                );
              }

              // Use latest team data, fallback to initial if loading
              final teamData =
                  teamSnapshot.hasData && teamSnapshot.data!.data() != null
                  ? teamSnapshot.data!.data() as Map<String, dynamic>
                  : widget.initialTeamData;

              final String teamName = teamData['teamName'] ?? "Team";
              final double teamBudget = (teamData['monthlyBudget'] ?? 0.0)
                  .toDouble();

              return Column(
                children: [
                  // --- UNIFIED HEADER ---
                  _buildHeader(context, teamName, teamData),

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
                          return Center(
                            child: CircularProgressIndicator(
                              color: context.textSecondary,
                              strokeWidth: 2,
                            ),
                          );
                        }

                        final membersDocs = membersSnapshot.data?.docs ?? [];
                        final String memberCount =
                            "${membersDocs.length} Members";

                        // Sort members by cost (Highest to lowest)
                        final sortedMembers = membersDocs.toList();
                        sortedMembers.sort((a, b) {
                          final costA =
                              ((a.data() as Map<String, dynamic>)['monthlyCost']
                                      as num?)
                                  ?.toDouble() ??
                              0.0;
                          final costB =
                              ((b.data() as Map<String, dynamic>)['monthlyCost']
                                      as num?)
                                  ?.toDouble() ??
                              0.0;
                          return costB.compareTo(costA);
                        });

                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),

                              // --- HERO STATS (Actual Expenses This Month + Member Salaries) ---
                              // Uses the already-fetched membersDocs from the outer StreamBuilder
                              // to include salaries, so no extra Firestore read is needed.
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('expenses')
                                    .where(
                                      'uid',
                                      isEqualTo: FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.uid,
                                    )
                                    .where('TeamId', isEqualTo: widget.teamId)
                                    .snapshots(),
                                builder: (context, expenseSnapshot) {
                                  double totalSpentThisMonth = 0.0;
                                  if (expenseSnapshot.hasData) {
                                    final now = DateTime.now();

                                    // Build raw list from Firestore docs
                                    final rawList = expenseSnapshot.data!.docs
                                        .map((doc) {
                                          final data =
                                              doc.data()
                                                  as Map<String, dynamic>;
                                          return {...data, 'id': doc.id};
                                        })
                                        .toList();

                                    // Expand recurring expenses into individual occurrences for the entire month
                                    final endOfMonth = DateTime(
                                      now.year,
                                      now.month + 1,
                                      0,
                                      23,
                                      59,
                                      59,
                                    );
                                    final expanded =
                                        ExpenseExpansionHelper.expandExpenses(
                                          rawList,
                                          maxDate: endOfMonth,
                                          allowFuture: true,
                                        );

                                    // Sum only non-salary expense occurrences in the current month.
                                    // Salary expenses are counted below from the members collection
                                    // to avoid double-counting if a salary doc also exists.
                                    for (final data in expanded) {
                                      if (data['isFunding'] == true) continue;
                                      final category = (data['Category'] ?? '')
                                          .toString()
                                          .toLowerCase();
                                      if (category == 'salary') continue;

                                      final rawDate =
                                          data['Date'] ?? data['date'];
                                      DateTime? date;
                                      if (rawDate is Timestamp) {
                                        date = rawDate.toDate();
                                      } else if (rawDate is DateTime) {
                                        date = rawDate;
                                      }
                                      if (date != null &&
                                          date.month == now.month &&
                                          date.year == now.year) {
                                        totalSpentThisMonth +=
                                            (data['Amount'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                      }
                                    }

                                    // Add member salaries from already-fetched membersDocs
                                    for (var memberDoc in membersDocs) {
                                      final md =
                                          memberDoc.data()
                                              as Map<String, dynamic>;
                                      final status =
                                          md['status']?.toString() ?? 'Active';
                                      if (status != 'Active') continue;
                                      final salary =
                                          double.tryParse(
                                            (md['salary'] ?? md['Salary'])
                                                    ?.toString() ??
                                                '0',
                                          ) ??
                                          0.0;
                                      totalSpentThisMonth += salary;
                                    }
                                  }
                                  final bool isWithinBudget =
                                      totalSpentThisMonth <= teamBudget;
                                  return _buildHeroStats(
                                    totalSpentThisMonth,
                                    isWithinBudget,
                                    teamName,
                                    teamData,
                                  );
                                },
                              ),

                              const SizedBox(height: 48),

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

  Widget _buildHeader(
    BuildContext context,
    String teamName,
    Map<String, dynamic> teamData,
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
                color: context.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              child: Icon(
                Icons.arrow_back,
                color: context.textPrimary,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              teamName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Satoshi',
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Settings / Edit Team is now balanced cleanly on the right
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditTeamScreen(teamId: widget.teamId, teamData: teamData),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              child: Icon(
                Icons.settings_outlined,
                color: context.textPrimary,
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
      title.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Satoshi',
        color: context.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildHeroStats(
    double totalCost,
    bool isWithinBudget,
    String teamName,
    Map<String, dynamic> teamData,
  ) {
    final budget = (teamData['monthlyBudget'] as num?)?.toDouble();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text(
                  "TOTAL MONTHLY COST",
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    color: context.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.formatByCountryCompact(
                      totalCost,
                      _userCountryCode,
                    ),
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      color: context.textPrimary,
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isWithinBudget
                        ? const Color(0xFF30D158).withValues(alpha: 0.1)
                        : const Color(0xFFFF453A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isWithinBudget ? "Within Budget" : "Over Budget",
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      color: isWithinBudget
                          ? const Color(0xFF30D158)
                          : const Color(0xFFFF453A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- SEAMLESS EXPENSES BUTTON ---
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeamExpenseHistoryScreen(
                    teamId: widget.teamId,
                    teamName: teamName,
                    monthlyBudget: budget,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: context.isDarkMode
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.02),
                border: Border(top: BorderSide(color: context.borderColor)),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: context.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "View Expense History",
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      color: context.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
    final double rawCost = (member['monthlyCost'] ?? 0.0).toDouble();
    final String salary =
        "${CurrencyFormatter.formatByCountryCompact(rawCost, _userCountryCode)}/mo";

    final String status = member['status'] ?? 'Active';
    final bool isPaused = status == 'Paused';

    final String? telegramFileId = member['telegramFileId'];
    final String? avatarUrl = member['avatarUrl'];

    final String? telegramFileIdFromAvatar =
        (avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            !avatarUrl.startsWith('http') &&
            !avatarUrl.contains('ui-avatars.com'))
        ? avatarUrl
        : null;

    return GestureDetector(
      onTap: () {
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
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
                          color: context.cardBackground,
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
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: isPaused
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: context.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role,
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        color: context.textSecondary,
                        fontSize: 13,
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
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      color: isPaused
                          ? context.textSecondary
                          : context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        _showMemberOptions(context, memberId, name, isPaused),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      color: Colors.transparent,
                      child: Icon(
                        Icons.more_vert,
                        color: context.textSecondary,
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

  Widget _buildEmptyState(String message) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Satoshi',
            color: context.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showMemberOptions(
    BuildContext context,
    String memberId,
    String memberName,
    bool isCurrentlyPaused,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBackground,
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
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "MANAGE $memberName".toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    color: context.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),

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
        color: Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? const Color(0xFFFF453A)
                  : context.textPrimary,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Satoshi',
                color: isDestructive
                    ? const Color(0xFFFF453A)
                    : context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(
    String name,
    double size,
    String avatarUrl,
    String? telegramFileId,
  ) {
    if (telegramFileId != null && telegramFileId.isNotEmpty) {
      return FutureBuilder<String>(
        future: TelegramService.getImageUrl(telegramFileId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: context.cardBackground,
                shape: BoxShape.circle,
                border: Border.all(color: context.borderColor),
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.3,
                  height: size * 0.3,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.textSecondary,
                  ),
                ),
              ),
            );
          } else if (snapshot.hasError || !snapshot.hasData) {
            return AvatarWidget(
              name: name,
              size: size,
              imageUrl: null,
              fontSize: size * 0.4,
            );
          } else {
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
}
