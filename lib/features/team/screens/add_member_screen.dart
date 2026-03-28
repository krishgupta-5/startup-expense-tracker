import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import '../../../services/currency_formatter.dart';
import '../../../services/user_country_service.dart';

class AddMemberScreen extends StatefulWidget {
  final String teamId;

  const AddMemberScreen({super.key, required this.teamId});

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

  String _userCountryCode = '+1'; // Default to USD
  final bool _isLoadingCountry = false; // Start as false since we use sync method

  // Cache for Telegram photos to avoid repeated fetching
  static final Map<String, String> _telegramPhotoCache = {};

  // 2. DATA LISTS
  late String _selectedTeamId;

  final Map<String, String> types = {
    'full_time': 'Full-time',
    'part_time': 'Part-time',
    'contractor': 'Contractor',
    'intern': 'Intern',
  };

  String _employmentType = "full_time";
  DateTime _joiningDate = DateTime.now();
  String? _telegramFileId;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    // Get country code synchronously for instant display
    _userCountryCode = UserCountryService.getUserCountryCodeSync();
    // Load in background for more accurate result
    _loadUserCountryCode();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _jobTitleController = TextEditingController();
    _costController = TextEditingController();

    _selectedTeamId = widget.teamId;
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
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _jobTitleController.dispose();
    _costController.dispose();
    super.dispose();
  }

  // --- FIREBASE LOGIC ---

  // Removed _fetchTeams since team assignment is now automatic

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

    // Team assignment validation removed since teamId is now required

    // Monthly cost is now mandatory
    if (_costController.text.trim().isEmpty) {
      _showErrorSnackBar(
        "Monthly cost is required. Please enter the member's monthly cost.",
      );
      return;
    }

    final double? cost = double.tryParse(_costController.text.trim());
    if (cost == null || cost < 0) {
      _showErrorSnackBar("Please enter a valid monthly cost.");
      return;
    }

    // Allow much higher amounts (up to 99 million)
    if (cost > 99999999.99) {
      _showErrorSnackBar(
        "Monthly cost amount is too high. Maximum allowed is 99,999,999.99",
      );
      return;
    }

    if (_joiningDate.isAfter(DateTime.now())) {
      _showErrorSnackBar("Joining date cannot be in the future.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final double cost = double.parse(_costController.text.trim());

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
        "avatarUrl": _telegramFileId ?? "",
        "telegramFileId": _telegramFileId ?? "",
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

  // --- TELEGRAM IMAGE UPLOAD METHODS ---
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
              "Upload Photo",
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

                      // --- TEAM INFO ---
                      _buildSectionLabel("TEAM ASSIGNMENT"),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.group, color: Colors.white38, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Member will be added to current team",
                                    style: GoogleFonts.inter(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Automatic team assignment",
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF30D158),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // --- EMPLOYMENT TYPE ---
                      _buildSectionLabel("EMPLOYMENT TYPE"),
                      const SizedBox(height: 16),
                      _buildSelectField(
                        label: "Type",
                        currentValue: _employmentType,
                        items: types,
                        onChanged: (val) =>
                            setState(() => _employmentType = val!),
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

  // Avatar Uploader with Telegram functionality
  Widget _buildAvatarUploader() {
    return GestureDetector(
      onTap: _showImagePicker,
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
                if (_telegramFileId != null)
                  FutureBuilder<String>(
                    future: getTelegramImageUrl(_telegramFileId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(
                          color: Colors.white38,
                          strokeWidth: 2,
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Icon(
                          Icons.person,
                          color: Colors.white12,
                          size: 48,
                        );
                      }
                      return ClipOval(
                        child: Image.network(
                          snapshot.data!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              color: Colors.white12,
                              size: 48,
                            );
                          },
                        ),
                      );
                    },
                  )
                else
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
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(
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
            _telegramFileId != null
                ? "Photo uploaded to Telegram"
                : "Upload Photo",
            style: GoogleFonts.inter(
              color: _telegramFileId != null
                  ? const Color(0xFF30D158)
                  : Colors.white38,
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
              CurrencyFormatter.getCurrencySymbol(_userCountryCode),
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
