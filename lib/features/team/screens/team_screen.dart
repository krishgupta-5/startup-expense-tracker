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
  List<QueryDocumentSnapshot> _filterAndSortTeams(
    List<QueryDocumentSnapshot> docs,
  ) {
    // A. Filter by Search Query
    List<QueryDocumentSnapshot> teams = docs;

    if (_searchQuery.isNotEmpty) {
      teams = teams.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final teamName = (data['teamName'] ?? '').toString().toLowerCase();
        return teamName.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // B. Apply sorting
    teams.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      switch (_selectedSortOption) {
        case "Name":
          final nameA = (dataA['teamName'] ?? '').toString().toLowerCase();
          final nameB = (dataB['teamName'] ?? '').toString().toLowerCase();
          return _selectedOrder == "A-Z"
              ? nameA.compareTo(nameB)
              : nameB.compareTo(nameA);

        case "Monthly Amount":
          final costA = (dataA['monthlyBudget'] ?? 0.0) as double;
          final costB = (dataB['monthlyBudget'] ?? 0.0) as double;
          return _selectedOrder == "Low-High"
              ? costA.compareTo(costB)
              : costB.compareTo(costA);

        case "Team Size":
          // Placeholder logic since actual team size isn't implemented in DB yet
          // Treating Team Lead as 1 member for now
          int sizeA = dataA['teamLeadAvatar'] != null ? 1 : 0;
          int sizeB = dataB['teamLeadAvatar'] != null ? 1 : 0;
          return _selectedOrder == "Low-High"
              ? sizeA.compareTo(sizeB)
              : sizeB.compareTo(sizeA);

        default:
          return 0;
      }
    });

    return teams;
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .where('uid', isEqualTo: user.uid)
          .snapshots(),
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

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("You don't have any teams yet.");
        }

        // Apply Local Filter & Sort
        final docs = _filterAndSortTeams(snapshot.data!.docs);

        if (docs.isEmpty) {
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
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _buildTeamCard(context, docs[index]);
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
        if (!_isSearching)
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

  Widget _buildTeamCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final name = data['teamName'] ?? 'Unnamed Team';
    final rawCost = data['monthlyBudget'] ?? 0.0;
    final cost = "₹${rawCost.toStringAsFixed(2)}";
    final color = _getColorFromName(data['color'] ?? 'blue');
    final icon = _getIconFromData(data);

    // We haven't implemented full member adding yet, so we'll use the Lead Avatar if it exists
    final List<String> avatars = [];
    if (data['teamLeadAvatar'] != null) {
      avatars.add(data['teamLeadAvatar']);
    }

    // Display string for members count
    final memberCountStr = avatars.isEmpty
        ? "0 Members"
        : "${avatars.length} Member(s)";

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          // Pass the team ID to details screen (you'll need to update TeamDetailScreen to accept this)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TeamDetailScreen(teamId: doc.id, initialTeamData: data),
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
              Divider(color: Colors.white.withValues(alpha: 0.04), height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Avatar Pile
                  _buildAvatarPile(avatars, []),

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

  Widget _buildAvatarPile(List<String> images, List<String> names) {
    if (images.isEmpty && names.isEmpty) {
      return Text(
        "No members",
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
      );
    }

    // Use names if available, otherwise generate placeholder names
    final List<String> displayNames = names.isNotEmpty
        ? names
        : List.generate(images.length, (index) => "Member ${index + 1}");

    return SizedBox(
      height: 24,
      width: 100, // Fixed width to allow stacking
      child: Stack(
        children: List.generate(
          (images.length > 3
              ? 3
              : images.length > displayNames.length
              ? displayNames.length
              : images.length),
          (index) {
            return Positioned(
              left: index * 18.0, // Overlap amount
              child: AvatarWidget(
                name: displayNames[index],
                size: 24,
                imageUrl:
                    images.length > index &&
                        images[index].isNotEmpty &&
                        !images[index].contains('ui-avatars.com')
                    ? images[index]
                    : null,
                fontSize: 8.0,
              ),
            );
          },
        ),
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
