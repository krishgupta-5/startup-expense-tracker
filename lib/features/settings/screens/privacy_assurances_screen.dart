import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyAssurancesScreen extends StatelessWidget {
  const PrivacyAssurancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Premium Header
              _buildHeader(context, "Privacy Assurances"),

              // 2. Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // --- HERO SECTION ---
                      Text(
                        "Your data belongs to you.",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "We believe financial privacy is a fundamental right. Here is exactly how we handle your information.",
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // --- ASSURANCE CARDS ---
                      _buildSectionLabel("SECURITY STANDARDS"),
                      const SizedBox(height: 8),
                      _buildAssuranceCard(
                        Icons.lock_outline,
                        "Zero-Knowledge Encryption",
                        "Your data is encrypted on your device before it reaches our servers. Only you hold the keys.",
                      ),
                      const SizedBox(height: 16),
                      _buildAssuranceCard(
                        Icons.visibility_off_outlined,
                        "No Ad Tracking",
                        "We do not sell, rent, or share your personal data with advertisers or third parties.",
                      ),
                      const SizedBox(height: 16),
                      _buildAssuranceCard(
                        Icons.storage,
                        "Data Residency",
                        "All your financial records are stored in enterprise-grade data centers within your region (India).",
                      ),
                      const SizedBox(height: 16),
                      _buildAssuranceCard(
                        Icons.delete_outline,
                        "Right to Erasure",
                        "Delete your account and every single byte of your data is permanently wiped from our backups instantly.",
                      ),

                      const SizedBox(height: 48),

                      // --- CERTIFICATION BADGE ---
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(
                                0xFF30D158,
                              ).withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(20),
                            color: const Color(
                              0xFF30D158,
                            ).withValues(alpha: 0.05),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF30D158),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "SOC2 Compliant & ISO 27001 Certified",
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF30D158),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context, String title) {
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
                color: Colors.white.withValues(
                  alpha: 0.05,
                ), // White Glass Style
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Spacer for balance
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildAssuranceCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container matching SettingsScreen design
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05), // Glassy fill
              borderRadius: BorderRadius.circular(12), // Match rounded squares
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
