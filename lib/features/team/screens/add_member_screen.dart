import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  // 1. CONTROLLERS & STATE
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _costController;

  bool _isLoading = false;
  bool _isLoadingTeams = true;

  // 2. DATA LISTS
  Map<String, String> _teams = {}; // Will be populated from Firebase
  String? _selectedTeamId;

  final Map<String, String> types = {
    'full_time': 'Full-time',
    'part_time': 'Part-time',
    'contractor': 'Contractor',
    'intern': 'Intern',
  };

  String _employmentType = "full_time";
  DateTime _joiningDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _jobTitleController = TextEditingController();
    _costController = TextEditingController();

    _fetchTeams();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _jobTitleController.dispose();
    _costController.dispose();
    super.dispose();
  }

  // --- FIREBASE LOGIC ---

  Future<void> _fetchTeams() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('uid', isEqualTo: uid)
          .get();

      final Map<String, String> fetchedTeams = {};
      for (var doc in snapshot.docs) {
        fetchedTeams[doc.id] = doc.data()['teamName'] ?? 'Unnamed Team';
      }

      if (mounted) {
        setState(() {
          _teams = fetchedTeams;
          if (_teams.isNotEmpty) {
            _selectedTeamId = _teams.keys.first;
          }
          _isLoadingTeams = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching teams: $e");
      if (mounted) {
        setState(() => _isLoadingTeams = false);
      }
    }
  }

  Future<void> _saveMember() async {
    // Basic Validation
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter member's name.");
      return;
    }

    if (_nameController.text.trim().length < 2) {
      _showErrorSnackBar("Name must be at least 2 characters long.");
      return;
    }

    if (_nameController.text.trim().length > 50) {
      _showErrorSnackBar("Name must not exceed 50 characters.");
      return;
    }

    if (_emailController.text.trim().isNotEmpty) {
      final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      );
      if (!emailRegex.hasMatch(_emailController.text.trim())) {
        _showErrorSnackBar("Please enter a valid email address.");
        return;
      }
    }

    if (_jobTitleController.text.trim().length > 100) {
      _showErrorSnackBar("Job title must not exceed 100 characters.");
      return;
    }

    if (_selectedTeamId == null) {
      _showErrorSnackBar("Please create a team first before adding members.");
      return;
    }

    if (_costController.text.trim().isNotEmpty) {
      final double? cost = double.tryParse(_costController.text.trim());
      if (cost == null || cost < 0) {
        _showErrorSnackBar("Please enter a valid monthly cost.");
        return;
      }

      if (cost > 999999.99) {
        _showErrorSnackBar("Monthly cost amount is too high.");
        return;
      }
    }

    if (_joiningDate.isAfter(DateTime.now())) {
      _showErrorSnackBar("Joining date cannot be in the future.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final double cost = _costController.text.trim().isEmpty
          ? 0.0
          : double.tryParse(_costController.text.trim())!;

      await FirebaseFirestore.instance.collection('members').add({
        "uid": FirebaseAuth.instance.currentUser!.uid,
        "teamId": _selectedTeamId, // Links this member to the specific team
        "fullName": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "jobTitle": _jobTitleController.text.trim(),
        "joiningDate": _joiningDate,
        "employmentType": _employmentType,
        "monthlyCost": cost,
        "createdAt": FieldValue.serverTimestamp(),
        // "avatarUrl": "" // TODO: Implement avatar upload later
      });

      debugPrint("Member added successfully with teamId: $_selectedTeamId");

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Member added successfully!",
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF30D158),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message ?? 'Failed to add member');
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

                      // --- AVATAR UPLOADER ---
                      // Left in the UI as a placeholder, no functionality yet
                      Center(child: _buildAvatarUploader()),
                      const SizedBox(height: 40),

                      // --- PERSONAL DETAILS ---
                      _buildSectionLabel("PERSONAL DETAILS"),
                      const SizedBox(height: 16),
                      _buildTextInput(
                        "Full Name",
                        "e.g. Sarah Miller",
                        Icons.person_outline,
                        _nameController,
                      ),
                      const SizedBox(height: 16),
                      _buildTextInput(
                        "Email Address",
                        "sarah@company.com",
                        Icons.email_outlined,
                        _emailController,
                      ),
                      const SizedBox(height: 16),
                      _buildTextInput(
                        "Job Title",
                        "e.g. Senior Product Designer",
                        Icons.badge_outlined,
                        _jobTitleController,
                      ),

                      const SizedBox(height: 32),

                      // --- JOINING DATE ---
                      _buildSectionLabel("JOINING DATE"),
                      const SizedBox(height: 16),
                      _buildDateSelector(),

                      const SizedBox(height: 32),

                      // --- ASSIGNMENT ---
                      _buildSectionLabel("TEAM ASSIGNMENT"),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _isLoadingTeams
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : _teams.isEmpty
                                ? Text(
                                    "No teams found",
                                    style: GoogleFonts.inter(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                    ),
                                  )
                                : _buildSelectField(
                                    label: "Team",
                                    currentValue: _selectedTeamId,
                                    items: _teams,
                                    onChanged: (val) =>
                                        setState(() => _selectedTeamId = val),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSelectField(
                              label: "Type",
                              currentValue: _employmentType,
                              items: types,
                              onChanged: (val) =>
                                  setState(() => _employmentType = val!),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // --- COMPENSATION ---
                      _buildSectionLabel("COMPENSATION"),
                      const SizedBox(height: 16),
                      _buildSalaryInput(),
                      const SizedBox(height: 8),
                      Text(
                        "This amount will be added to your monthly burn rate.",
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // 3. Save Button
              _buildSaveButton(),
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
            "Add Member",
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

  // Placeholder Avatar Uploader (No functionality yet)
  Widget _buildAvatarUploader() {
    return GestureDetector(
      onTap: () {
        // TODO: Implement image picker and Firebase Storage upload
        debugPrint("Avatar uploader tapped - implement later!");
      },
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.person, color: Colors.white12, size: 48),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Upload Photo (Coming Soon)",
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput(
    String hint,
    String placeholder,
    IconData icon,
    TextEditingController controller,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.white38, size: 20),
          hintText: placeholder,
          labelText: hint,
          labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
          hintStyle: GoogleFonts.inter(color: Colors.white12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  Widget _buildSalaryInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF30D158).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "₹",
              style: GoogleFonts.inter(
                color: Color(0xFF30D158),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "MONTHLY COST",
                  style: GoogleFonts.inter(
                    color: Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextField(
                  controller: _costController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: "0.00",
                    hintStyle: GoogleFonts.inter(color: Colors.white12),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectField({
    required String label,
    required String? currentValue,
    required Map<String, String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: ShadSelect<String>(
            placeholder: Text(
              'Select $label',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
            ),
            initialValue: currentValue,
            options: [
              ...items.entries.map(
                (e) => ShadOption(value: e.key, child: Text(e.value)),
              ),
            ],
            selectedOptionBuilder: (context, value) => Text(
              items[value]!,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
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

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: TextField(
            readOnly: true,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              icon: const Icon(
                Icons.calendar_today,
                color: Colors.white38,
                size: 20,
              ),
              hintText: "Select joining date",
              labelText: "Joining Date",
              labelStyle: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 13,
              ),
              hintStyle: GoogleFonts.inter(color: Colors.white12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              suffixIcon: const Icon(
                Icons.calendar_month,
                color: Colors.white38,
              ),
            ),
            controller: TextEditingController(
              text:
                  "${_joiningDate.day}/${_joiningDate.month}/${_joiningDate.year}",
            ),
            onTap: () {
              _showShadCalendar();
            },
          ),
        ),
      ],
    );
  }

  void _showShadCalendar() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF09090B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Joining Date",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white38),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ShadCalendar(
                  selected: _joiningDate,
                  fromMonth: DateTime(_joiningDate.year - 5),
                  toMonth: DateTime(_joiningDate.year + 2, 12),
                  onChanged: (DateTime? date) {
                    if (date != null) {
                      setState(() {
                        _joiningDate = date;
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Done",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
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
          onPressed: _isLoading ? null : _saveMember,
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
                  "Add Member",
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
