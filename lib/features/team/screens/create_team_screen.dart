import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  // 1. CONTROLLERS & STATE
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _budgetController;

  bool _isLoading = false;

  String _selectedColor = "Blue";
  IconData _selectedIcon = Icons.code;

  // Manage selected team lead avatar
  String _selectedLead = "https://i.pravatar.cc/150?img=11";

  // 2. DATA OPTIONS
  final List<Map<String, dynamic>> _colors = [
    {"name": "Blue", "color": const Color(0xFF0A84FF)},
    {"name": "Orange", "color": const Color(0xFFFF9F0A)},
    {"name": "Purple", "color": const Color(0xFFA259FF)},
    {"name": "Green", "color": const Color(0xFF30D158)},
    {"name": "Red", "color": const Color(0xFFFF453A)},
  ];

  final List<IconData> _icons = [
    Icons.code,
    Icons.campaign_outlined,
    Icons.brush_outlined,
    Icons.attach_money,
    Icons.security,
    Icons.support_agent,
  ];

  final List<String> _teamLeads = [
    "https://i.pravatar.cc/150?img=11",
    "https://i.pravatar.cc/150?img=33",
    "https://i.pravatar.cc/150?img=5",
    "https://i.pravatar.cc/150?img=9",
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _budgetController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  // 3. FIREBASE UPLOAD LOGIC
  Future<void> _createTeam() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter a team name.");
      return;
    }

    if (_nameController.text.trim().length < 2) {
      _showErrorSnackBar("Team name must be at least 2 characters long.");
      return;
    }

    if (_nameController.text.trim().length > 30) {
      _showErrorSnackBar("Team name must not exceed 30 characters.");
      return;
    }

    if (_descController.text.trim().isNotEmpty &&
        _descController.text.trim().length > 200) {
      _showErrorSnackBar("Description must not exceed 200 characters.");
      return;
    }

    if (_budgetController.text.trim().isNotEmpty) {
      final double? budget = double.tryParse(_budgetController.text.trim());
      if (budget == null || budget < 0) {
        _showErrorSnackBar("Please enter a valid budget amount.");
        return;
      }

      if (budget > 999999.99) {
        _showErrorSnackBar("Budget amount is too high.");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final id = const Uuid().v4();
      final double budget = _budgetController.text.trim().isEmpty
          ? 0.0
          : double.tryParse(_budgetController.text.trim())!;

      // Storing to a new 'teams' collection
      await FirebaseFirestore.instance.collection('teams').doc(id).set({
        "uid": FirebaseAuth.instance.currentUser!.uid,
        "teamName": _nameController.text.trim(),
        "description": _descController.text.trim(),
        "monthlyBudget": budget,
        "color": _selectedColor,
        // Save icon data safely so we can rebuild it later
        "iconCodePoint": _selectedIcon.codePoint,
        "iconFontFamily": _selectedIcon.fontFamily,
        "teamLeadAvatar": _selectedLead,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Team created successfully!",
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF30D158),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message ?? 'Failed to create team');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Header
              _buildHeader(context),

              // 2. Scrollable Form
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // --- TEAM NAME INPUT ---
                      Text(
                        "TEAM NAME",
                        style: GoogleFonts.inter(
                          color: Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: const Color(0xFF30D158),
                        decoration: InputDecoration(
                          hintText: "e.g. Engineering",
                          hintStyle: GoogleFonts.inter(
                            color: Colors.white12,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),

                      // -----------------------
                      const SizedBox(height: 40),

                      // --- VISUAL IDENTITY ---
                      _buildSectionLabel("TEAM IDENTITY"),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Color Picker
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: _colors
                                  .map((c) => _buildColorOption(c))
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                            Divider(
                              color: Colors.white.withValues(alpha: 0.04),
                              height: 1,
                            ),
                            const SizedBox(height: 24),
                            // Icon Picker
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: _icons
                                  .map((i) => _buildIconOption(i))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),

                      // -----------------------
                      const SizedBox(height: 32),

                      // Description
                      _buildTextInput(
                        "DESCRIPTION",
                        "What does this team do?",
                        _descController,
                        maxLines: 3,
                      ),

                      const SizedBox(height: 32),

                      // Budget
                      _buildTextInput(
                        "MONTHLY BUDGET",
                        "0.00",
                        _budgetController,
                        maxLines: 1,
                        isNumber: true,
                      ),

                      const SizedBox(height: 32),

                      // Team Lead
                      _buildSectionLabel("ASSIGN TEAM LEAD"),
                      const SizedBox(height: 16),
                      _buildTeamSelector(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // 3. Create Button
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context) {
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
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
          Text(
            "New Team",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildTextInput(
    String label,
    String placeholder,
    TextEditingController controller, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            maxLines: maxLines,
            minLines: maxLines > 1 ? 3 : 1,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.inter(color: Colors.white24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              prefixIcon: isNumber
                  ? const Icon(
                      Icons.currency_rupee,
                      color: Colors.white38,
                      size: 18,
                    )
                  : null,
              prefixIconConstraints: isNumber
                  ? const BoxConstraints(minWidth: 32, minHeight: 0)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorOption(Map<String, dynamic> colorData) {
    final bool isSelected = _selectedColor == colorData['name'];
    final Color color = colorData['color'];

    return GestureDetector(
      onTap: () => setState(() => _selectedColor = colorData['name']),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: color, width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  Widget _buildIconOption(IconData icon) {
    final bool isSelected = _selectedIcon == icon;

    return GestureDetector(
      onTap: () => setState(() => _selectedIcon = icon),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.white54,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTeamSelector() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._teamLeads.map(
            (url) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => setState(() => _selectedLead = url),
                child: _buildAvatar(url, isSelected: _selectedLead == url),
              ),
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.search, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url, {bool isSelected = false}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: const Color(0xFF30D158), width: 2)
            : Border.all(color: Colors.transparent),
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      child: isSelected
          ? Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Color(0xFF30D158),
                size: 18,
              ),
            )
          : null,
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: Colors.white24,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _createTeam,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white54,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Text(
                  "Create Team",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
