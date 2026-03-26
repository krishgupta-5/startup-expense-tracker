import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'company_details_screen.dart';
import 'edit_profile_screen.dart';
import 'statements_screen.dart';
import 'rate_us_screen.dart';
import 'change_password.dart';
import 'data_access_screen.dart';
import 'privacy_assurances_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // 1. Header (Back & Title)
              _buildHeader(context),

              const SizedBox(height: 32),

              // 2. Profile Section (Now fully reactive!)
              _buildProfileSection(context),

              const SizedBox(height: 40),

              // 3. Company & Statements
              _buildSectionLabel("ORGANIZATION"),
              _buildSettingsGroup([
                _buildTile(
                  icon: Icons.business,
                  title: "Company Details",
                  subtitle: "Manage address, funding, and structure",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CompanyDetailsScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.description_outlined,
                  title: "Statements",
                  subtitle: "Expense reports and exports",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ExpensesExportScreen(),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 32),

              // 4. Security & Data
              _buildSectionLabel("SECURITY & PRIVACY"),
              _buildSettingsGroup([
                _buildTile(
                  icon: Icons.lock_outline,
                  title: "Change Password",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: "Data Access Control",
                  subtitle: "Manage team permissions",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DataAccessScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.security,
                  title: "Privacy Assurances",
                  subtitle: "How we protect your financial data",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyAssurancesScreen(),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 32),

              // 5. Support
              _buildSectionLabel("SUPPORT"),
              _buildSettingsGroup([
                _buildTile(
                  icon: Icons.star_outline,
                  title: "Rate us on Play Store",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RateUsScreen(),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 40),

              // 6. Logout
              _buildLogoutButton(),

              const SizedBox(height: 24),

              // 7. Version
              Text(
                "Version 1.0.2 (Build 402)",
                style: GoogleFonts.inter(
                  color: Colors.white24,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context) {
    return Center(
      child: Text(
        "Settings",
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox();
    }

    // StreamBuilder listens directly to the Firestore document for instant updates
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String name = user.displayName ?? 'User';
        String email = user.email ?? 'No email';

        // Override with Firestore data if available
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] ?? name;
          email = data['email'] ?? email;
        }

        return Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF09090B),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  "Edit Profile",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white54, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.04),
      indent: 58,
    );
  }

  Widget _buildLogoutButton() {
    return Builder(
      builder: (context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            // AuthWrapper / NavigationWrapper will handle redirect automatically
            // via its auth stream listener. No manual navigation needed.
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F1F22),
            foregroundColor: const Color(0xFFFF453A),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: const Color(0xFFFF453A).withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Text(
            "Log Out",
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}