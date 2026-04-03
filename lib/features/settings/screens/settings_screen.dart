import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'company_details_screen.dart';
import 'edit_profile_screen.dart';
import 'statements_screen.dart';
import 'change_password.dart';
import 'privacy_assurances_screen.dart';
import 'budget_settings_screen.dart';
import '../widgets/coming_soon_dialog.dart';
import '../../../services/currency_preference_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Cache for Telegram photos to avoid repeated fetching
  static final Map<String, String> _telegramPhotoCache = {};

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

  String _selectedCurrency = '+1';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrencyPreference();

    // Listen for currency changes
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
  }

  @override
  void dispose() {
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    super.dispose();
  }

  void _onCurrencyChanged() {
    if (mounted) {
      if (kDebugMode) print('Currency changed listener triggered');
      setState(() {
        _selectedCurrency =
            CurrencyPreferenceService.getCurrencyPreferenceSync();
        if (kDebugMode) {
          print('Updated _selectedCurrency to: $_selectedCurrency');
        }
      });
    }
  }

  Future<void> _loadCurrencyPreference() async {
    if (kDebugMode) print('Settings: Loading currency preference');
    setState(() => _isLoading = true);
    try {
      final currency = await CurrencyPreferenceService.getCurrencyPreference();
      if (kDebugMode) print('Settings: Loaded currency: $currency');
      if (mounted) {
        setState(() {
          _selectedCurrency = currency;
          if (kDebugMode) {
            print('Settings: Set _selectedCurrency to: $_selectedCurrency');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Settings: Error loading currency: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showCurrencySelector() async {
    final availableCurrencies =
        CurrencyPreferenceService.getAvailableCurrencies();

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true, // Allow proper height calculation
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // Handle keyboard
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height *
                0.7, // Max 70% of screen height
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Currency',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableCurrencies.length,
                  itemBuilder: (context, index) {
                    final currency = availableCurrencies[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            await _updateCurrency(currency['code']!);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _selectedCurrency == currency['code']
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedCurrency == currency['code']
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  currency['symbol']!,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    currency['name']!,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (_selectedCurrency == currency['code'])
                                  const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateCurrency(String currencyCode) async {
    if (kDebugMode) {
      print('Settings: Starting currency update to: $currencyCode');
    }
    setState(() => _isLoading = true);

    try {
      final success = await CurrencyPreferenceService.updateCurrencyPreference(
        currencyCode,
      );

      if (kDebugMode) print('Settings: Currency update result: $success');

      if (success && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Currency updated to ${CurrencyPreferenceService.getCurrencyDisplayName(currencyCode)}',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF00C851),
            duration: const Duration(seconds: 2),
          ),
        );

        // Reload the app to apply currency changes everywhere
        await _reloadApp();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update currency',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFF453A),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Settings: Exception during currency update: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating currency',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFF453A),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reloadApp() async {
    if (kDebugMode) print('Settings: Starting app reload');

    // Force rebuild of the entire app by restarting the widget tree
    if (mounted) {
      // Go back to home screen first
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Show a brief message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applying currency changes...',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00C851),
          duration: const Duration(seconds: 1),
        ),
      );

      // Force a complete rebuild by pushing a replacement route
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        if (kDebugMode) print('Settings: Navigating to home screen');
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Premium Header
              _buildHeader(context),

              const SizedBox(height: 32),

              // 2. Profile Section (Fully reactive)
              Center(child: _buildProfileSection(context)),

              const SizedBox(height: 48),

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

              // 4. Preferences
              _buildSectionLabel("PREFERENCES"),
              _buildSettingsGroup([
                _buildTile(
                  icon: Icons.currency_exchange,
                  title: "Currency",
                  subtitle: CurrencyPreferenceService.getCurrencyDisplayName(
                    _selectedCurrency,
                  ),
                  onTap: _showCurrencySelector,
                  trailing: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          CurrencyPreferenceService.getCurrencySymbol(
                            _selectedCurrency,
                          ),
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                _buildDivider(),
                _buildTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: "Budget Settings",
                  subtitle: "Set budget for ALL expense categories",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BudgetSettingsScreen(),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 32),

              // 5. Security & Data
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
                    showDialog(
                      context: context,
                      builder: (context) => const ComingSoonDialog(),
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
                    showDialog(
                      context: context,
                      builder: (context) => const ComingSoonDialog(),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 48),

              // 6. Logout
              _buildLogoutButton(),

              const SizedBox(height: 32),

              // 7. Version
              Center(
                child: Text(
                  "Version 1.0.2 (Build 402)",
                  style: GoogleFonts.inter(
                    color: Colors.white24,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context) {
    return Text(
      "Settings",
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 28, // Scaled up to match Home/Overview screens
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Build profile avatar with Telegram photo support
  Widget _buildProfileAvatar(String? profileImageFileId) {
    if (profileImageFileId != null && profileImageFileId.isNotEmpty) {
      // Show uploaded profile image
      return FutureBuilder<String>(
        future: getTelegramImageUrl(profileImageFileId),
        builder: (context, snapshot) {
          return Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: snapshot.hasData
                  ? Image.network(
                      snapshot.data!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar();
                      },
                    )
                  : _buildDefaultAvatar(),
            ),
          );
        },
      );
    }

    // Show default avatar
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        color: const Color(0xFF141416),
      ),
      child: const Icon(Icons.person, size: 40, color: Colors.white38),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox();
    }

    // StreamBuilder listens to both user and company documents for complete profile data
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("companies")
              .doc(user.uid)
              .snapshots(),
          builder: (context, companySnapshot) {
            String name = user.displayName ?? 'User';
            String email = user.email ?? 'No email';

            // Override with user document data if available
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
              name = userData['name'] ?? name;
              email = userData['email'] ?? email;
            }

            // Priority: Use owner name from company data if available
            if (companySnapshot.hasData && companySnapshot.data!.exists) {
              final companyData =
                  companySnapshot.data!.data() as Map<String, dynamic>;
              name = companyData['Owner Name'] ?? name;
            }

            // Load profile image FileId from user data
            String? profileImageFileId;
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
              profileImageFileId = userData['profileImageFileId'];
            }

            return Column(
              children: [
                Stack(
                  children: [
                    _buildProfileAvatar(profileImageFileId),
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
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
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
                      color: Colors.white.withValues(
                        alpha: 0.05,
                      ), // Glassy white
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: 0.15,
                        ), // Crisp border
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
      },
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(
          24,
        ), // Updated to 24 for larger cards
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
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.05,
                  ), // White Glass Icon background
                  borderRadius: BorderRadius.circular(12),
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
              ?trailing,
              if (trailing == null)
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white24,
                  size: 20,
                ),
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
      indent: 76, // 20 padding + 40 icon width + 16 gap
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
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(
              0xFFFF453A,
            ).withValues(alpha: 0.1), // Soft Red fill
            foregroundColor: const Color(0xFFFF453A),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: const Color(
                  0xFFFF453A,
                ).withValues(alpha: 0.2), // Red border
              ),
            ),
          ),
          child: Text(
            "Log Out",
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
