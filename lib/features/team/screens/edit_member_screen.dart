import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../../../widgets/avatar_widget.dart';

class EditMemberScreen extends StatefulWidget {
  final String memberId;
  final Map<String, dynamic> memberData;

  const EditMemberScreen({
    super.key,
    required this.memberId,
    required this.memberData,
  });

  @override
  State<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends State<EditMemberScreen> {
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _emailController;

  bool _isLoading = false;
  bool _isLoadingTeams = true;

  Map<String, String> _teams = {};
  String? _selectedTeamId;

  // Telegram photo variables
  String? _telegramFileId;
  String? _fileName;

  // Cache for Telegram photos to avoid repeated fetching
  static final Map<String, String> _telegramPhotoCache = {};

  final Map<String, String> _statuses = {
    'Active': 'Active',
    'Paused': 'Paused',
    'On Leave': 'On Leave',
  };

  late String _status;
  late DateTime _joiningDate;

  @override
  void initState() {
    super.initState();

    // Pre-fill with existing member data
    _nameController = TextEditingController(
      text: widget.memberData['fullName'] ?? "",
    );
    _roleController = TextEditingController(
      text: widget.memberData['jobTitle'] ?? "",
    );
    _emailController = TextEditingController(
      text: widget.memberData['email'] ?? "",
    );

    _status = widget.memberData['status'] ?? "Active";
    _selectedTeamId = widget.memberData['teamId'];

    // Initialize Telegram file ID from member data
    _telegramFileId =
        widget.memberData['telegramFileId'] ?? widget.memberData['avatarUrl'];

    if (widget.memberData['joiningDate'] != null &&
        widget.memberData['joiningDate'] is Timestamp) {
      _joiningDate = (widget.memberData['joiningDate'] as Timestamp).toDate();
    } else {
      _joiningDate = DateTime.now();
    }

    _fetchTeams();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    super.dispose();
  }

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

          // If the team this member belonged to was deleted, reset to first available
          if (_selectedTeamId != null && !_teams.containsKey(_selectedTeamId)) {
            _selectedTeamId = _teams.isNotEmpty ? _teams.keys.first : null;
          }

          _isLoadingTeams = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching teams: $e");
      if (mounted) setState(() => _isLoadingTeams = false);
    }
  }

  Future<void> _updateMember() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar("Name cannot be empty");
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

    if (_roleController.text.trim().length > 100) {
      _showErrorSnackBar("Job title must not exceed 100 characters.");
      return;
    }

    if (_joiningDate.isAfter(DateTime.now())) {
      _showErrorSnackBar("Joining date cannot be in the future.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> updateData = {
        "fullName": _nameController.text.trim(),
        "jobTitle": _roleController.text.trim(),
        "email": _emailController.text.trim(),
        "teamId": _selectedTeamId,
        "status": _status,
        "joiningDate": _joiningDate,
      };

      // Update Telegram file ID if image was changed
      if (_telegramFileId != null &&
          _telegramFileId != widget.memberData['telegramFileId']) {
        updateData["avatarUrl"] = _telegramFileId;
        updateData["telegramFileId"] = _telegramFileId;
      }

      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .update(updateData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Profile updated successfully",
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF30D158),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message ?? 'Failed to update profile');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    // Check for Telegram photo first, then regular avatar
    final String? telegramFileId = widget.memberData['telegramFileId'];
    final String? avatarUrl = widget.memberData['avatarUrl'];

    // Determine if avatarUrl contains a Telegram file ID (for backward compatibility)
    final String? telegramFileIdFromAvatar =
        (avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            !avatarUrl.startsWith('http') &&
            !avatarUrl.contains('ui-avatars.com'))
        ? avatarUrl
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Edit Profile",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.only(right: 20.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xFF0A84FF),
                      strokeWidth: 2,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _updateMember,
                  child: Text(
                    "SAVE",
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0A84FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar Edit with Telegram photo support
            Stack(
              alignment: Alignment.center,
              children: [
                _buildMemberAvatar(
                  _nameController.text,
                  100,
                  _telegramFileId ?? telegramFileId ?? telegramFileIdFromAvatar,
                ),
                GestureDetector(
                  onTap: _showImagePicker,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _buildInput("FULL NAME", _nameController),
            const SizedBox(height: 24),
            _buildInput("JOB TITLE", _roleController),
            const SizedBox(height: 24),
            _buildInput("EMAIL", _emailController),
            const SizedBox(height: 24),

            // Joining Date
            _buildSectionLabel("JOINING DATE"),
            const SizedBox(height: 16),
            _buildDateSelector(),
            const SizedBox(height: 24),

            // Team Select
            _isLoadingTeams
                ? const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white38,
                  )
                : _teams.isEmpty
                ? Text(
                    "No teams found.",
                    style: GoogleFonts.inter(color: Colors.redAccent),
                  )
                : _buildSelect(
                    "TEAM",
                    _selectedTeamId,
                    _teams,
                    (val) => setState(() => _selectedTeamId = val),
                  ),
            const SizedBox(height: 24),

            // Status Select
            _buildSelect(
              "STATUS",
              _status,
              _statuses,
              (val) => setState(() => _status = val!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSelect(
    String label,
    String? value,
    Map<String, String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
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
            initialValue: value,
            options: [
              ...items.entries.map(
                (e) => ShadOption(value: e.key, child: Text(e.value)),
              ),
            ],
            selectedOptionBuilder: (context, selectedValue) => Text(
              items[selectedValue] ?? "Select",
              style: GoogleFonts.inter(color: Colors.white),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Container(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
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
          hintStyle: GoogleFonts.inter(color: Colors.white12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        controller: TextEditingController(
          text:
              "${_joiningDate.day}/${_joiningDate.month}/${_joiningDate.year}",
        ),
        onTap: () {
          _showShadCalendar();
        },
      ),
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

  // Build member avatar with Telegram photo support
  Widget _buildMemberAvatar(String name, double size, String? telegramFileId) {
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
      // Fallback to generated avatar
      return AvatarWidget(
        name: name,
        size: size,
        imageUrl: null,
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

  // --- IMAGE UPLOAD METHODS ---
  Future<void> _showImagePicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _buildImagePickerSheet(),
    );
  }

  Widget _buildImagePickerSheet() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              "Update Photo",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePickerOption(
                  Icons.camera_alt,
                  "Camera",
                  () => _pickImage(ImageSource.camera),
                ),
                _buildImagePickerOption(
                  Icons.photo_library,
                  "Gallery",
                  () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        final File? croppedFile = await _cropImage(File(image.path));
        if (croppedFile != null) {
          await _uploadImageToTelegram(croppedFile);
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      _showErrorSnackBar("Failed to pick image");
    }
  }

  Future<File?> _cropImage(File sourceFile) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: sourceFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: const Color(0xFF141416),
            toolbarWidgetColor: Colors.white,
            backgroundColor: const Color(0xFF09090B),
            activeControlsWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            minimumAspectRatio: 1.0,
          ),
        ],
      );
      return croppedFile != null ? File(croppedFile.path) : null;
    } catch (e) {
      debugPrint("Error cropping image: $e");
      return sourceFile;
    }
  }

  Future<void> _uploadImageToTelegram(File imageFile) async {
    try {
      setState(() => _isLoading = true);
      _fileName = imageFile.path.split('/').last;

      final fileId = await uploadToTelegram(imageFile.path);

      if (fileId == null) {
        throw Exception('Failed to upload image to Telegram');
      }

      if (mounted) {
        setState(() {
          _telegramFileId = fileId;
          _isLoading = false;
        });
        debugPrint("Image uploaded to Telegram successfully: $fileId");
      }
    } catch (e) {
      debugPrint("Error uploading image to Telegram: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        _fileName = null;
        _showErrorSnackBar("Failed to upload image to Telegram");
      }
    }
  }

  Future<String?> uploadToTelegram(String filePath) async {
    try {
      await dotenv.load(fileName: ".env.local");
      final botToken = dotenv.env['TELEGRAM_BOT_TOKEN'];

      if (botToken == null) {
        throw Exception('Telegram bot token not found in environment');
      }

      final uri = Uri.parse("https://api.telegram.org/bot$botToken/sendPhoto");

      var request = http.MultipartRequest('POST', uri);
      request.fields['chat_id'] = '-1003885930746';

      request.files.add(await http.MultipartFile.fromPath('photo', filePath));

      final response = await request.send();

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);

        // Take highest quality image
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
