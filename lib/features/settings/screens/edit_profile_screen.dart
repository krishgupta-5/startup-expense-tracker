import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:developer';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final String email = FirebaseAuth.instance.currentUser!.email!;

  // Country Code State
  String _selectedCountryCode = "+91";
  String _selectedFlag = "🇮🇳";

  final List<Map<String, String>> _countryCodes = [
    {"code": "+1", "flag": "🇺🇸", "name": "United States"},
    {"code": "+91", "flag": "🇮🇳", "name": "India"},
    {"code": "+44", "flag": "🇬🇧", "name": "United Kingdom"},
    {"code": "+61", "flag": "🇦🇺", "name": "Australia"},
    {"code": "+81", "flag": "🇯🇵", "name": "Japan"},
    {"code": "+49", "flag": "🇩🇪", "name": "Germany"},
    {"code": "+33", "flag": "🇫🇷", "name": "France"},
    {"code": "+971", "flag": "🇦🇪", "name": "United Arab Emirates"},
    {"code": "+65", "flag": "🇸🇬", "name": "Singapore"},
  ];

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> loadUserProfile() async {
    try {
      // First try to get data from companies collection (company setup data)
      final companySnapshot = await FirebaseFirestore.instance
          .collection("companies")
          .doc(uid)
          .get();

      // Also get user data as fallback
      final userSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      setState(() {
        // Default values
        _nameController.text = '';
        _phoneController.text = '';
        _locationController.text = '';
        _emailController.text = email;

        // Priority: Use company data if available (from company setup)
        if (companySnapshot.exists) {
          final companyData = companySnapshot.data()!;
          _nameController.text = companyData["Owner Name"] ?? '';

          // Parse mobile number to extract country code and phone number
          String fullMobileNumber = companyData["Mobile Number"] ?? '';
          if (fullMobileNumber.isNotEmpty) {
            // Find the first space to separate country code from phone number
            int spaceIndex = fullMobileNumber.indexOf(' ');
            if (spaceIndex != -1) {
              String countryCode = fullMobileNumber.substring(0, spaceIndex);
              String phoneNumber = fullMobileNumber
                  .substring(spaceIndex + 1)
                  .trim();

              // Set the country code if it matches one of our codes
              for (var country in _countryCodes) {
                if (country["code"] == countryCode) {
                  _selectedCountryCode = countryCode;
                  _selectedFlag = country["flag"]!;
                  break;
                }
              }
              _phoneController.text = phoneNumber;
            } else {
              // If no space found, treat entire string as phone number with default country code
              _phoneController.text = fullMobileNumber;
            }
          }

          _locationController.text = companyData["Country Location"] ?? '';
        }

        // Fallback: Use user data if company data not available
        if (userSnapshot.exists && _nameController.text.isEmpty) {
          final userData = userSnapshot.data()!;
          _nameController.text = userData['name'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
          _locationController.text = userData['location'] ?? '';
        }

        // Email always comes from Firebase Auth or user collection
        if (userSnapshot.exists) {
          final userData = userSnapshot.data()!;
          _emailController.text = userData['email'] ?? email;
        }
      });
    } catch (e) {
      log('Profile data fetch error: $e');
    }
  }

  Future<bool> updateUserProfile() async {
    try {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF141416),
          content: Text(
            "Updating profile...",
            style: GoogleFonts.inter(color: Colors.white),
          ),
          duration: const Duration(milliseconds: 800),
        ),
      );

      // Update Firebase Auth profile
      await FirebaseAuth.instance.currentUser?.updateDisplayName(
        _nameController.text.trim(),
      );

      // Update user profile in users collection
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "phone": _phoneController.text.trim(),
        "location": _locationController.text.trim(),
        "uid": uid,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update companies collection with the same field names as company setup
      final String fullMobileNumber =
          "$_selectedCountryCode ${_phoneController.text.trim()}";
      await FirebaseFirestore.instance.collection("companies").doc(uid).set({
        "Owner Name": _nameController.text.trim(),
        "Mobile Number": fullMobileNumber,
        "Country Location": _locationController.text.trim(),
        "Email": _emailController.text.trim(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF453A),
            content: Text(
              "Error updating profile: ${e.toString()}",
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      _buildAvatarEdit(),
                      const SizedBox(height: 40),
                      _buildInputGroup(
                        "FULL NAME",
                        _nameController,
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 24),
                      _buildInputGroup(
                        "EMAIL ADDRESS",
                        _emailController,
                        Icons.email_outlined,
                      ),
                      const SizedBox(height: 24),
                      _buildPhoneInputGroup(),
                      const SizedBox(height: 24),
                      _buildInputGroup(
                        "LOCATION",
                        _locationController,
                        Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
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
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          Text(
            "Edit Profile",
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

  Widget _buildAvatarEdit() {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            image: const DecorationImage(
              image: NetworkImage("https://i.pravatar.cc/150?img=12"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF09090B), width: 4),
            ),
            child: const Icon(Icons.camera_alt, size: 18, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildInputGroup(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
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
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              icon: Icon(icon, color: Colors.white38, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              isDense: true,
            ),
          ),
        ),
      ],
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
          onPressed: () async {
            final success = await updateUserProfile();
            if (mounted) {
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF30D158),
                    content: Text(
                      "Profile updated successfully!",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            "Save Changes",
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInputGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "PHONE NUMBER",
          style: GoogleFonts.inter(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showCountryCodePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Text(
                        "$_selectedFlag $_selectedCountryCode",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white60,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                height: 24,
                width: 1,
                color: Colors.white.withValues(alpha: 0.1),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: "98765 43210",
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCountryCodePicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF141416),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Select Country Code",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white38,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _countryCodes.length,
                    itemBuilder: (context, index) {
                      final country = _countryCodes[index];
                      final isSelected =
                          _selectedCountryCode == country["code"];

                      return ListTile(
                        onTap: () {
                          setState(() {
                            _selectedCountryCode = country["code"]!;
                            _selectedFlag = country["flag"]!;
                          });
                          Navigator.pop(context);
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: Text(
                          country["flag"]!,
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(
                          country["name"]!,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: Text(
                          country["code"]!,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : Colors.white38,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
