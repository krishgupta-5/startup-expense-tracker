import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup_expense_tracker/features/team/screens/create_team_screen.dart';
import 'package:startup_expense_tracker/features/team/screens/member_detail_screen.dart';
import 'team_detail_screen.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/currency_preference_service.dart';
import '../../../services/telegram_service.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> with WidgetsBindingObserver {
  // 1. Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isSearching = false;

  // 2. Filter State (Defaults)
  String _selectedSortOption = "Name";
  String _selectedOrder = "A-Z"; // Default order

  // Refresh state
  String _userCountryCode = '+1'; // Default to USD

  // Cache for the last sort future to prevent rebuilding on every stream tick
  Future<List<Map<String, dynamic>>>? _sortedTeamsFuture;
  List<Map<String, dynamic>>? _lastTeamsData;
  String _lastTeamsFingerprint = '';

  /// Lightweight content fingerprint so sort cache invalidation detects
  /// field-level changes in addition to list-length changes.
  String _teamsFingerprint(List<Map<String, dynamic>> teams) =>
      teams
          .map((t) => '${t['id']}:${t['teamName']}:${t['monthlyBudget']}')
          .join('|');

  void _rebuildSortFuture(List<Map<String, dynamic>> teams) {
    _lastTeamsData = teams;
    _lastTeamsFingerprint = _teamsFingerprint(teams);
    _sortedTeamsFuture = _filterAndSortTeams(teams);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
    _loadUserCountryCode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    _searchController.dispose();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _refreshData() {
    setState(() {});
  }

  IconData _getIconFromData(Map<String, dynamic> data) {
    if (data['iconCodePoint'] != null && data['iconFontFamily'] != null) {
      switch (data['iconCodePoint']) {
        case 0xe3af:
          return Icons.work;
        case 0xe0af:
          return Icons.business;
        case 0xe7fd:
          return Icons.group;
        case 0xe226:
          return Icons.code;
        case 0xe86c:
          return Icons.design_services;
        case 0xe85d:
          return Icons.computer;
        case 0xe53b:
          return Icons.build;
        case 0xe251:
          return Icons.lightbulb;
        case 0xe7f1:
          return Icons.trending_up;
        case 0xe8b6:
          return Icons.people;
        default:
          return Icons.group;
      }
    }
    return Icons.group; 
  }

  Color _getColorFromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'blue':
        return const Color(0xFF0A84FF);
      case 'orange':
        return const Color(0xFFFF9F0A);
      case 'purple':
        return const Color(0xFFA259FF);
      case 'green':
        return const Color(0xFF30D158);
      case 'red':
        return const Color(0xFFFF453A);
      default:
        return const Color(0xFF0A84FF); 
    }
  }

  Stream<List<Map<String, dynamic>>> _getTeamsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('teams')
        .where('uid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          List<Map<String, dynamic>> allTeams = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            allTeams.add({...data, 'id': doc.id, 'source': 'teams_collection'});
          }

          return allTeams;
        });
  }

  Future<List<Map<String, dynamic>>> _filterAndSortTeams(
    List<Map<String, dynamic>> teams,
  ) async {
    List<Map<String, dynamic>> filteredTeams = List.from(teams);

    if (_searchQuery.isNotEmpty) {
      filteredTeams = filteredTeams.where((team) {
        final teamName = (team['teamName'] ?? '').toString().toLowerCase();
        return teamName.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_selectedSortOption == "Team Size") {
      final user = FirebaseAuth.instance.currentUser;
      final teamSizes = <String, int>{};

      if (user != null) {
        final allMembersSnap = await FirebaseFirestore.instance
            .collection('members')
            .where('uid', isEqualTo: user.uid)
            .get();

        for (final doc in allMembersSnap.docs) {
          final tId = doc.data()['teamId'] as String?;
          if (tId != null) teamSizes[tId] = (teamSizes[tId] ?? 0) + 1;
        }
      }

      filteredTeams.sort((a, b) {
        final sizeA = teamSizes[a['id'] as String] ?? 0;
        final sizeB = teamSizes[b['id'] as String] ?? 0;
        return _selectedOrder == "Low-High"
            ? sizeA.compareTo(sizeB)
            : sizeB.compareTo(sizeA);
      });
    } else {
      filteredTeams.sort((a, b) {
        switch (_selectedSortOption) {
          case "Name":
            final nameA = (a['teamName'] ?? '').toString().toLowerCase();
            final nameB = (b['teamName'] ?? '').toString().toLowerCase();
            return _selectedOrder == "A-Z"
                ? nameA.compareTo(nameB)
                : nameB.compareTo(nameA);

          case "Monthly Amount":
            final costA = (a['monthlyBudget'] ?? 0).toDouble();
            final costB = (b['monthlyBudget'] ?? 0).toDouble();
            return _selectedOrder == "Low-High"
                ? costA.compareTo(costB)
                : costB.compareTo(costA);

          default:
            return 0;
        }
      });
    }

    return filteredTeams;
  }

  void _toggleOrder(String option) {
    setState(() {
      if (_selectedSortOption == option) {
        if (option == "Name") {
          _selectedOrder = _selectedOrder == "A-Z" ? "Z-A" : "A-Z";
        } else {
          _selectedOrder = _selectedOrder == "Low-High"
              ? "High-Low"
              : "Low-High";
        }
      } else {
        _selectedSortOption = option;
        if (option == "Name") {
          _selectedOrder = "A-Z";
        } else {
          _selectedOrder = "High-Low";
        }
      }
      if (_lastTeamsData != null) {
        _sortedTeamsFuture = _filterAndSortTeams(_lastTeamsData!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF09090B),
        floatingActionButton: _isSearching
            ? null 
            : FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateTeamScreen(),
                    ),
                  ).then((_) {
                    _refreshData();
                  });
                },
                backgroundColor: Colors.white, 
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  "New Team",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: _buildHeader(),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle(
                      _isSearching ? "SEARCH RESULTS" : "YOUR TEAMS",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!_isSearching)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildFilterChips(),
                ),

              if (!_isSearching) const SizedBox(height: 24),

              Expanded(child: _buildFirebaseTeamsStream()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFirebaseTeamsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildEmptyState("Please log in.");

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getTeamsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint("Firebase Error: ${snapshot.error}");
          return _buildEmptyState("Error loading teams.");
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState("You don't have any teams yet.");
        }

        final newTeams = snapshot.data!;
        final newFingerprint = _teamsFingerprint(newTeams);
        if (_sortedTeamsFuture == null ||
            _lastTeamsFingerprint != newFingerprint) {
          _rebuildSortFuture(newTeams);
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _sortedTeamsFuture,
          builder: (context, futureSnapshot) {
            if (futureSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white38,
                ),
              );
            }

            if (futureSnapshot.hasError) {
              debugPrint("Sorting Error: ${futureSnapshot.error}");
              return _buildEmptyState("Error sorting teams.");
            }

            final teams = futureSnapshot.data ?? [];

            if (teams.isEmpty) {
              return _buildEmptyState("No teams match your search.");
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100), 
              physics: const BouncingScrollPhysics(),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                return _buildTeamCard(context, teams[index]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _buildFilterChip(
            label: "Name",
            icon: Icons.sort_by_alpha,
            isSelected: _selectedSortOption == "Name",
          ),
          const SizedBox(width: 12),
          _buildFilterChip(
            label: "Monthly Amount",
            icon: Icons.attach_money,
            isSelected: _selectedSortOption == "Monthly Amount",
          ),
          const SizedBox(width: 12),
          _buildFilterChip(
            label: "Team Size",
            icon: Icons.group_outlined,
            isSelected: _selectedSortOption == "Team Size",
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    IconData arrowIcon;
    if (isSelected) {
      if (label == "Name") {
        arrowIcon = _selectedOrder == "A-Z"
            ? Icons.arrow_downward
            : Icons.arrow_upward;
      } else {
        arrowIcon = _selectedOrder == "High-Low"
            ? Icons.arrow_downward
            : Icons.arrow_upward;
      }
    } else {
      arrowIcon = Icons.arrow_downward; // default, won't be shown
    }

    return GestureDetector(
      onTap: () => _toggleOrder(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF141416),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(arrowIcon, color: Colors.black, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _isSearching
              ? _buildActiveSearchBar()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Organization",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Teams Overview",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
        ),
        if (!_isSearching) ...[
          GestureDetector(
            onTap: () {
              setState(() {
                _isSearching = true;
              });
            },
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: const Icon(Icons.search, color: Colors.white, size: 20),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActiveSearchBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: "Search teams...",
                hintStyle: GoogleFonts.inter(
                  color: Colors.white24,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  if (_lastTeamsData != null) {
                    _sortedTeamsFuture = _filterAndSortTeams(_lastTeamsData!);
                  }
                });
              },
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isSearching = false;
                _searchQuery = "";
                _searchController.clear();
              });
            },
            child: const Icon(Icons.close, color: Colors.white54, size: 20),
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

  Widget _buildTeamCard(BuildContext context, Map<String, dynamic> teamData) {
    final String name = teamData['teamName'] ?? 'Unnamed Team';
    final Color color = _getColorFromName(teamData['color'] ?? 'blue');
    final IconData icon = _getIconFromData(teamData);
    final String teamId = teamData['id'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TeamDetailScreen(teamId: teamId, initialTeamData: teamData),
            ),
          ).then((_) => _refreshData());
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('members')
              .where('teamId', isEqualTo: teamId)
              .snapshots(),
          builder: (context, membersSnapshot) {
            final membersDocs = membersSnapshot.data?.docs ?? [];
            final int memberCount = membersDocs.length;
            final String memberCountStr =
                membersSnapshot.connectionState == ConnectionState.waiting
                    ? 'Loading...'
                    : (memberCount == 1
                        ? '1 Member'
                        : '$memberCount Members');

            final List<Map<String, dynamic>> avatarInfos = membersDocs
                .take(3)
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String? tgId = data['telegramFileId'] as String?;
                  final String? url = data['avatarUrl'] as String?;
                  final String? legacyTgId = (url != null &&
                          url.isNotEmpty &&
                          !url.startsWith('http') &&
                          !url.contains('ui-avatars.com'))
                      ? url
                      : null;
                  return <String, dynamic>{
                    'name': data['fullName'] ?? 'Unnamed',
                    'avatarUrl': url ?? '',
                    'telegramFileId':
                        (tgId != null && tgId.isNotEmpty) ? tgId : legacyTgId,
                    'memberId': doc.id,
                  };
                })
                .toList();

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                memberCountStr,
                                style: GoogleFonts.inter(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white24,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.04),
                    height: 1,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildAvatarRow(avatarInfos),
                      // --- NEW: Live Spent / Budget Visualizer ---
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('expenses')
                            .where('TeamId', isEqualTo: teamId)
                            .snapshots(),
                        builder: (context, expenseSnap) {
                          double actualSpent = 0.0;
                          if (expenseSnap.hasData) {
                            final now = DateTime.now();
                            for (var doc in expenseSnap.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final date = (data['Date'] as Timestamp?)?.toDate();
                              if (date != null &&
                                  date.month == now.month &&
                                  date.year == now.year) {
                                actualSpent += (data['Amount'] as num?)?.toDouble() ?? 0.0;
                              }
                            }
                          }

                          final budget = (teamData['monthlyBudget'] ?? 0).toDouble();
                          final isOverBudget = actualSpent > budget && budget > 0;
                          
                          final spentStr = CurrencyFormatter.formatByCountryCompact(actualSpent, _userCountryCode);
                          final budgetStr = CurrencyFormatter.formatByCountryCompact(budget, _userCountryCode);
                          
                          double progress = budget > 0 ? (actualSpent / budget) : 0.0;
                          if (progress > 1.0) progress = 1.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    spentStr,
                                    style: GoogleFonts.inter(
                                      color: isOverBudget ? const Color(0xFFFF453A) : Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    " / $budgetStr",
                                    style: GoogleFonts.inter(
                                      color: Colors.white38,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 80,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isOverBudget ? const Color(0xFFFF453A) : const Color(0xFF30D158),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatarRow(List<Map<String, dynamic>> avatarInfos) {
    if (avatarInfos.isEmpty) {
      return Text(
        "No members yet",
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
      );
    }

    return SizedBox(
      height: 28,
      width: 100,
      child: Stack(
        children: List.generate(avatarInfos.length, (index) {
          final info = avatarInfos[index];
          return Positioned(
            left: index * 20.0,
            child: GestureDetector(
              onTap: () => _showMemberProfile(info['memberId'] as String),
              child: _buildMemberAvatarWithTelegram(
                info['name'] as String,
                28,
                info['avatarUrl'] as String,
                info['telegramFileId'] as String?,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMemberAvatarWithTelegram(
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
                color: const Color(0xFF141416),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.3,
                  height: size * 0.3,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white38,
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

  void _showMemberProfile(String memberId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemberDetailScreen(memberId: memberId),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Icon(
              Icons.group_off_outlined,
              color: Colors.white12,
              size: 48,
            ), 
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}