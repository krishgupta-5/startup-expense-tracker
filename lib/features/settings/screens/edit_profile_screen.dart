import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Controllers pre-filled with User Context
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final String email = FirebaseAuth.instance.currentUser!.email!;

  @override
  void initState() {
    loadUserProfile();
    super.initState();
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
      final snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data()!;

        setState(() {
          _nameController.text = data['name'] ?? '';
          _emailController.text = email;
          _phoneController.text = data['phone'] ?? '';
          _locationController.text = data['location'] ?? '';
        });
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> updateUserProfile() async {
    try {
      // Update user profile in users collection
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "name": _nameController.text,
        "email": _emailController.text,
        "phone": _phoneController.text,
        "location": _locationController.text,
        "uid": uid,
        "updatedAt": Timestamp.now(),
      }, SetOptions(merge: true));

      // Sync name to companies collection
      await _syncNameToCompanies();
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _syncNameToCompanies() async {
    try {
      final companySnapshot = await FirebaseFirestore.instance
          .collection("companies")
          .where("uid", isEqualTo: uid)
          .limit(1)
          .get();

      if (companySnapshot.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection("companies")
            .doc(companySnapshot.docs.first.id)
            .set({
              "Owner Name": _nameController.text,
              "updatedAt": Timestamp.now(),
            }, SetOptions(merge: true));
      }
    } catch (e) {
      print(e.toString());
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
                    children: [
                      const SizedBox(height: 32),

                      // Avatar Editor
                      _buildAvatarEdit(),

                      const SizedBox(height: 40),

                      // Form Fields
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
                      _buildInputGroup(
                        "PHONE NUMBER",
                        _phoneController,
                        Icons.phone_outlined,
                      ),
                      const SizedBox(height: 24),
                      _buildInputGroup(
                        "LOCATION",
                        _locationController,
                        Icons.location_on_outlined,
                      ),

                      const SizedBox(height: 100), // Spacing for bottom button
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
          // Placeholder to balance the row
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
              image: NetworkImage(
                "https://i.pravatar.cc/150?img=12",
              ), // Placeholder
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
          onPressed: () {
            updateUserProfile();
            Navigator.pop(context);
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
}
