import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
// NOTE: Ensure these files exist or comment them out if testing in isolation
import 'team_detail_screen.dart';

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

  // 3. Data Source
  final List<Map<String, dynamic>> _allTeams = [
    {
      "name": "Engineering",
      "members": "12 Members",
      "cost": "\$62,400",
      "icon": Icons.code,
      "color": const Color(0xFF0A84FF),
      "avatars": [
        "https://i.pravatar.cc/150?img=11",
        "https://i.pravatar.cc/150?img=3",
        "https://i.pravatar.cc/150?img=68",
      ],
    },
    {
      "name": "Marketing",
      "members": "5 Members",
      "cost": "\$18,200",
      "icon": Icons.campaign_outlined,
      "color": const Color(0xFFFF9F0A),
      "avatars": [
        "https://i.pravatar.cc/150?img=9",
        "https://i.pravatar.cc/150?img=47",
      ],
    },
    {
      "name": "Product Design",
      "members": "4 Members",
      "cost": "\$22,000",
      "icon": Icons.brush_outlined,
      "color": const Color(0xFFA259FF),
      "avatars": ["https://i.pravatar.cc/150?img=5"],
    },
    {
      "name": "Sales",
      "members": "8 Members",
      "cost": "\$35,500",
      "icon": Icons.attach_money,
      "color": const Color(0xFF30D158),
      "avatars": [
        "https://i.pravatar.cc/150?img=12",
        "https://i.pravatar.cc/150?img=33",
      ],
    },
  ];

  // 4. Filter Logic
  List<Map<String, dynamic>> get _filteredTeams {
    List<Map<String, dynamic>> teams = List.from(_allTeams);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      teams = teams
          .where(
            (team) => team['name'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }

    // Apply sorting
    switch (_selectedSortOption) {
      case "Name":
        teams.sort(
          (a, b) => _selectedOrder == "A-Z"
              ? a['name'].toString().compareTo(b['name'].toString())
              : b['name'].toString().compareTo(a['name'].toString()),
        );
        break;
      case "Team Size":
        teams.sort((a, b) {
          int aSize = int.parse(a['members'].toString().split(' ')[0]);
          int bSize = int.parse(b['members'].toString().split(' ')[0]);
          return _selectedOrder == "Low-High" ? aSize - bSize : bSize - aSize;
        });
        break;
      case "Monthly Amount":
        teams.sort((a, b) {
          int aCost = int.parse(
            a['cost'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
          );
          int bCost = int.parse(
            b['cost'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
          );
          return _selectedOrder == "Low-High" ? aCost - bCost : bCost - aCost;
        });
        break;
    }

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
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header with Search
              _buildHeader(),

              const SizedBox(height: 32),

              // 3. Section Title & Filter Component
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle(
                    _isSearching ? "SEARCH RESULTS" : "YOUR TEAMS",
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 4. NEW: Horizontal Filter Component (Chips)
              if (!_isSearching) _buildFilterChips(),

              if (!_isSearching) const SizedBox(height: 24),

              // 5. Teams List
              _filteredTeams.isEmpty
                  ? _buildEmptyState()
                  : _buildTeamsList(context),

              const SizedBox(height: 80), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      // Allow scroll to clip nicely
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
    // Determine arrow direction for display
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

  Widget _buildTeamsList(BuildContext context) {
    return Column(
      children: _filteredTeams
          .map((team) => _buildTeamCard(context, team))
          .toList(),
    );
  }

  Widget _buildTeamCard(BuildContext context, Map<String, dynamic> team) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TeamDetailScreen()),
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
                          color: (team['color'] as Color).withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          team['icon'],
                          color: team['color'],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team['name'],
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            team['members'],
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
                  _buildAvatarPile(team['avatars']),

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
                        team['cost'],
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

  Widget _buildAvatarPile(List<String> images) {
    return SizedBox(
      height: 24,
      width: 100, // Fixed width to allow stacking
      child: Stack(
        children: List.generate(images.length > 3 ? 3 : images.length, (index) {
          return Positioned(
            left: index * 18.0, // Overlap amount
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF141416),
                  width: 2,
                ), // Cutout effect
                image: DecorationImage(
                  image: NetworkImage(images[index]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Icon(Icons.search_off, color: Colors.white12, size: 48),
            const SizedBox(height: 16),
            Text(
              "No teams found",
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
