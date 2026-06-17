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
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  bool _needsRefresh = false;
  String _userCountryCode = '+1'; // Default to USD
  final bool _isLoadingCountry = false; 

  // Cache for Telegram photos to avoid repeated fetching
  static final Map<String, String> _telegramPhotoCache = {};

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
    if (state == AppLifecycleState.resumed && _needsRefresh) {
      setState(() {
        _needsRefresh = false;
      });
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
      final teamSizes = <String, int>{};

      for (final team in filteredTeams) {
        final membersSnapshot = await FirebaseFirestore.instance
            .collection('members')
            .where('teamId', isEqualTo: team['id'])
            .get();
        teamSizes[team['id'] as String] = membersSnapshot.docs.length;
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
            // FIX: Safely cast to double to prevent int-parsing crashes
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
    final name = teamData['teamName'] ?? 'Unnamed Team';
    // FIX: Safely cast to double
    final double rawCost = (teamData['monthlyBudget'] ?? 0).toDouble(); 
    
    final cost = _isLoadingCountry
        ? CurrencyFormatter.formatByCountry(rawCost, '+1')
        : CurrencyFormatter.formatByCountry(rawCost, _userCountryCode);
    final color = _getColorFromName(teamData['color'] ?? 'blue');
    final icon = _getIconFromData(teamData);
    final teamId = teamData['id'] as String;

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
          ).then((_) {
            _refreshData();
          });
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
                  _buildAvatarPile(teamData),
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
    final teamId = teamData['id'] as String;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('members')
          .where('teamId', isEqualTo: teamId)
          .snapshots(),
      builder: (context, membersSnapshot) {
        if (membersSnapshot.hasError) {
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

  Widget _buildAvatarPile(Map<String, dynamic> teamData) {
    final teamId = teamData['id'] as String;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('members')
          .where('teamId', isEqualTo: teamId)
          .snapshots(),
      builder: (context, membersSnapshot) {
        if (membersSnapshot.hasError) {
          return Text(
            "Error",
            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12),
          );
        }

        final membersDocs = membersSnapshot.data?.docs ?? [];
        final List<String> avatars = [];
        final List<String> names = [];
        final List<String> memberIds = [];

        for (var memberDoc in membersDocs) {
          final memberData = memberDoc.data() as Map<String, dynamic>;
          final String name = memberData['fullName'] ?? 'Unnamed';
          final String? avatarUrl = memberData['avatarUrl'];
          final String? telegramFileId = memberData['telegramFileId'];

          names.add(name);
          memberIds.add(memberDoc.id);

          if (telegramFileId != null && telegramFileId.isNotEmpty) {
            avatars.add('telegram:$telegramFileId'); 
          } else if (avatarUrl != null &&
              avatarUrl.isNotEmpty &&
              !avatarUrl.startsWith('http') &&
              !avatarUrl.contains('ui-avatars.com')) {
            avatars.add('telegram:$avatarUrl');
          } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
            avatars.add(avatarUrl);
          } else {
            avatars.add(''); 
          }
        }

        return _buildAvatarWidget(names, avatars, memberIds);
      },
    );
  }

  Widget _buildAvatarWidget(
    List<String> names,
    List<String> avatars,
    List<String> memberIds,
  ) {
    if (names.isEmpty) {
      return Text(
        "No members yet",
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
      );
    }

    return SizedBox(
      height: 28, 
      width: 100, 
      child: Stack(
        children: List.generate((names.length > 3 ? 3 : names.length), (index) {
          return Positioned(
            left: index * 20.0, 
            child: _buildMemberAvatar(
              names[index],
              avatars[index],
              memberIds[index],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMemberAvatar(String name, String avatarUrl, String? memberId) {
    return GestureDetector(
      onTap: () {
        if (memberId != null) {
          _showMemberProfile(memberId);
        }
      },
      child: _buildMemberAvatarWithTelegram(name, 28, avatarUrl),
    );
  }

  Widget _buildMemberAvatarWithTelegram(
    String name,
    double size,
    String avatarUrl,
  ) {
    if (avatarUrl.startsWith('telegram:')) {
      final telegramFileId = avatarUrl.substring(9); 
      return FutureBuilder<String>(
        future: getTelegramImageUrl(telegramFileId),
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
                  child: CircularProgressIndicator(
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

  Future<String> getTelegramImageUrl(String fileId) async {
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

      _telegramPhotoCache[fileId] = imageUrl;

      return imageUrl;
    } catch (e) {
      debugPrint('Error getting Telegram image URL: $e');
      rethrow;
    }
  }

  Future<String?> getTelegramFileId(String telegramFileId) async {
    try {
      await dotenv.load(fileName: ".env.local");
      final botToken = dotenv.env['TELEGRAM_BOT_TOKEN'];
      if (botToken == null) {
        throw Exception('Telegram bot token not found in environment');
      }

      final uri = Uri.parse("https://api.telegram.org/bot$botToken/sendPhoto");

      var request = http.MultipartRequest('POST', uri);
      request.fields['chat_id'] = '-1003885930746';
      request.files.add(
        await http.MultipartFile.fromPath('photo', telegramFileId),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var data = jsonDecode(responseData);

      if (data['ok']) {
        return data['result']['photo'].last['file_id'];
      } else {
        throw Exception("Upload failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('Error uploading to Telegram: $e');
      return null;
    }
  }
}