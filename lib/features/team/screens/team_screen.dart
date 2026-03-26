import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup_expense_tracker/features/team/screens/create_team_screen.dart';
import 'team_detail_screen.dart';
import '../../../widgets/avatar_widget.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  // 1. Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isSearching = false;

  // 2. Filter State (Defaults)
  String _selectedSortOption = "Name";
  String _selectedOrder = "A-Z"; // Default order

  // Reconstruct Icon from Font Family & Code Point saved in Firebase
  IconData _getIconFromData(Map<String, dynamic> data) {
    if (data['iconCodePoint'] != null && data['iconFontFamily'] != null) {
      // Use a switch statement with common icon code points to ensure tree shaking
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
    return Icons.group; // Fallback
  }

  // Parse color string to actual Color object
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
        return const Color(0xFF0A84FF); // Fallback
    }
  }

  // 3. Local Filter Logic for Firebase Docs
  Future<List<Map<String, dynamic>>> _getAllTeams() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      // 1. Fetch teams from teams collection (manually created teams)
      final teamsSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('uid', isEqualTo: user.uid)
          .get();

      // 2. Fetch teams from companies collection (company setup teams)
      final companySnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(user.uid)
          .get();

      List<Map<String, dynamic>> allTeams = [];

      // Add manually created teams
      for (var doc in teamsSnapshot.docs) {
        final data = doc.data();
        allTeams.add({...data, 'id': doc.id, 'source': 'teams_collection'});
      }

      // Add company setup teams
      if (companySnapshot.exists) {
        final companyData = companySnapshot.data() as Map<String, dynamic>;
        final List<dynamic> companyTeams = companyData['Teams'] ?? [];

        for (var team in companyTeams) {
          allTeams.add({
            'teamName': team['name'],
            'members': team['members'] ?? [],
            'monthlyBudget': 0.0, // Default budget for company setup teams
            'color': 'blue', // Default color
            'iconCodePoint': 0xe7fd, // Default group icon
            'iconFontFamily': 'MaterialIcons',
            'source': 'company_setup',
            'id':
                'company_setup_${team['name']}', // Unique ID for company setup teams
          });
        }
      }

      return allTeams;
    } catch (e) {
      debugPrint("Error fetching teams: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _filterAndSortTeams(
    List<Map<String, dynamic>> teams,
  ) async {
    // A. Filter by Search Query
    List<Map<String, dynamic>> filteredTeams = teams;

    if (_searchQuery.isNotEmpty) {
      filteredTeams = teams.where((team) {
        final teamName = (team['teamName'] ?? '').toString().toLowerCase();
        return teamName.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // B. Apply sorting
    if (_selectedSortOption == "Team Size") {
      // For team size, we need to fetch member counts asynchronously
      final teamSizes = <String, int>{};

      for (final team in filteredTeams) {
        if (team['source'] == 'company_setup') {
          // Company setup teams have members array directly
          final members = team['members'] as List<dynamic>? ?? [];
          teamSizes[team['id'] as String] = members.length;
        } else {
          // Manually created teams need to fetch from members collection
          final membersSnapshot = await FirebaseFirestore.instance
              .collection('members')
              .where('teamId', isEqualTo: team['id'])
              .get();
          teamSizes[team['id'] as String] = membersSnapshot.docs.length;
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
      // For synchronous sorting options
      filteredTeams.sort((a, b) {
        switch (_selectedSortOption) {
          case "Name":
            final nameA = (a['teamName'] ?? '').toString().toLowerCase();
            final nameB = (b['teamName'] ?? '').toString().toLowerCase();
            return _selectedOrder == "A-Z"
                ? nameA.compareTo(nameB)
                : nameB.compareTo(nameA);

          case "Monthly Amount":
            final costA = (a['monthlyBudget'] ?? 0.0) as double;
            final costB = (b['monthlyBudget'] ?? 0.0) as double;
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

  // Toggle order when the same chip is clicked again
  void _toggleOrder(String option) {
    setState(() {
      if (_selectedSortOption == option) {
        // Toggle existing order
        if (option == "Name") {
          _selectedOrder = _selectedOrder == "A-Z" ? "Z-A" : "A-Z";
        } else {
          _selectedOrder = _selectedOrder == "Low-High"
              ? "High-Low"
              : "Low-High";
        }
      } else {
        // Select new option and reset to default order
        _selectedSortOption = option;
        if (option == "Name") {
          _selectedOrder = "A-Z";
        } else {
          _selectedOrder = "High-Low"; // Default for numbers usually High-Low
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black, // Dark background
        // --- NEW TEAM BUTTON ---
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateTeamScreen()),
            );
          },
          backgroundColor: const Color(0xFF0A84FF),
          elevation: 4,
          icon: const Icon(Icons.add, color: Colors.white, size: 20),
          label: Text(
            "New Team",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header with Search (Fixed at top)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: _buildHeader(),
              ),

              // 2. Section Title
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

              // 3. Horizontal Filter Component (Chips)
              if (!_isSearching)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildFilterChips(),
                ),

              if (!_isSearching) const SizedBox(height: 24),

              // 4. Teams List (Scrollable Stream)
              Expanded(child: _buildFirebaseTeamsStream()),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildFirebaseTeamsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildEmptyState("Please log in.");

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllTeams(),
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

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _filterAndSortTeams(snapshot.data!),
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
              padding: const EdgeInsets.fromLTRB(
                24,
                0,
                24,
                100,
              ), // Bottom padding for FAB
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
    if (label == "Name") {
      arrowIcon = _selectedOrder == "A-Z"
          ? Icons.arrow_downward
          : Icons.arrow_upward;
    } else {
      arrowIcon = _selectedOrder == "High-Low"
          ? Icons.arrow_downward
          : Icons.arrow_upward;
    }

    return GestureDetector(
      onTap: () => _toggleOrder(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A84FF) : const Color(0xFF141416),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0A84FF)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(arrowIcon, color: Colors.white, size: 14),
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
        // Title or Active Search Bar
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

        // Search Toggle Button (only show if not already searching)
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
                borderRadius: BorderRadius.circular(12),
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
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search teams...",
                hintStyle: GoogleFonts.inter(color: Colors.white24),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
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
    debugPrint(
      "Building team card for team ID: ${teamData['id']}, team name: ${teamData['teamName']}",
    );

    final name = teamData['teamName'] ?? 'Unnamed Team';
    final rawCost = teamData['monthlyBudget'] ?? 0.0;
    final cost = "₹${rawCost.toStringAsFixed(2)}";
    final color = _getColorFromName(teamData['color'] ?? 'blue');
    final icon = _getIconFromData(teamData);
    final teamId = teamData['id'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          // Pass team data to details screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TeamDetailScreen(teamId: teamId, initialTeamData: teamData),
            ),
          );
        },
        child: Container(
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
                          // Member count display
                          _buildMemberCount(teamData),
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
              Divider(color: Colors.white.withValues(alpha: 0.04), height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Avatar Pile
                  _buildAvatarPile(teamData),
                  // Monthly Cost
                  Row(
                    children: [
                      Text(
                        "Monthly: ",
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        cost,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCount(Map<String, dynamic> teamData) {
    final source = teamData['source'] as String?;

    if (source == 'company_setup') {
      // Company setup teams have members array directly
      final members = teamData['members'] as List<dynamic>? ?? [];
      final memberCount = members.length;
      final memberCountStr = memberCount == 1
          ? "1 Member"
          : "$memberCount Members";

      return Text(
        memberCountStr,
        style: GoogleFonts.inter(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
    } else {
      // Manually created teams need to fetch from members collection
      final teamId = teamData['id'] as String;
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('members')
            .where('teamId', isEqualTo: teamId)
            .snapshots(),
        builder: (context, membersSnapshot) {
          if (membersSnapshot.hasError) {
            debugPrint("Error fetching members: ${membersSnapshot.error}");
            return Text(
              "Error loading members",
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            );
          }

          if (membersSnapshot.connectionState == ConnectionState.waiting) {
            return Text(
              "Loading...",
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            );
          }

          final memberCount = membersSnapshot.data?.docs.length ?? 0;
          debugPrint("Team $teamId has $memberCount members");

          final memberCountStr = memberCount == 1
              ? "1 Member"
              : "$memberCount Members";

          return Text(
            memberCountStr,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          );
        },
      );
    }
  }

  Widget _buildAvatarPile(Map<String, dynamic> teamData) {
    final source = teamData['source'] as String?;

    if (source == 'company_setup') {
      // Company setup teams have members array directly
      final members = teamData['members'] as List<dynamic>? ?? [];
      if (members.isEmpty) {
        return Text(
          "No members",
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
        );
      }

      final List<String> names = members
          .map(
            (member) =>
                (member as Map<String, dynamic>)['fullName']?.toString() ??
                'Unnamed',
          )
          .toList();

      return _buildAvatarWidget(names, []);
    } else {
      // Manually created teams need to fetch from members collection
      final teamId = teamData['id'] as String;
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('members')
            .where('teamId', isEqualTo: teamId)
            .snapshots(),
        builder: (context, membersSnapshot) {
          if (membersSnapshot.hasError) {
            debugPrint(
              "Error fetching members for avatars: ${membersSnapshot.error}",
            );
            return Text(
              "Error loading members",
              style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12),
            );
          }

          final membersDocs = membersSnapshot.data?.docs ?? [];
          debugPrint(
            "Avatar pile - Team $teamId has ${membersDocs.length} members",
          );

          final List<String> avatars = [];
          final List<String> names = [];

          for (var memberDoc in membersDocs) {
            final memberData = memberDoc.data() as Map<String, dynamic>;
            final String name = memberData['fullName'] ?? 'Unnamed';
            final String? avatarUrl = memberData['avatarUrl'];

            names.add(name);
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              avatars.add(avatarUrl);
            } else {
              avatars.add(''); // Empty string for generated avatar
            }
          }

          return _buildAvatarWidget(names, avatars);
        },
      );
    }
  }

  Widget _buildAvatarWidget(List<String> names, List<String> avatars) {
    if (names.isEmpty) {
      return Text(
        "No members",
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
      );
    }

    return SizedBox(
      height: 24,
      width: 100, // Fixed width to allow stacking
      child: Stack(
        children: List.generate((names.length > 3 ? 3 : names.length), (index) {
          return Positioned(
            left: index * 18.0, // Overlap amount
            child: AvatarWidget(
              name: names[index],
              size: 24,
              imageUrl:
                  avatars.length > index &&
                      avatars[index].isNotEmpty &&
                      !avatars[index].contains('ui-avatars.com')
                  ? avatars[index]
                  : null,
              fontSize: 8.0,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Icon(Icons.search_off, color: Colors.white12, size: 48),
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
