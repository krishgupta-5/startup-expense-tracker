import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:startup_expense_tracker/features/navigation/screens/main_navigation_wrapper.dart';
import 'dart:developer';

class CompanySetupScreen extends StatefulWidget {
  const CompanySetupScreen({super.key});

  @override
  State<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends State<CompanySetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 6;
  bool _isFinishing = false;

  // --- VALIDATION STATE ---
  final Set<String> _errors = {};

  // --- CONTROLLERS & STATE ---

  // Step 1: Identity
  final _ownerNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _countryController = TextEditingController();

  // Step 2: Legal & Loc
  final _addressController = TextEditingController();
  final _workDescController = TextEditingController();

  final companyTypes = {
    'sole_proprietorship': 'Sole Proprietorship',
    'partnership': 'Partnership',
    'llp': 'LLP',
    'pvt_ltd': 'Pvt Ltd',
  };
  String? _selectedCompanyType;

  // Step 3: Financials
  final TextEditingController _fundingController = TextEditingController();
  final TextEditingController _runwayController = TextEditingController();

  // Step 4: Bank (Dynamic List)
  final List<Map<String, TextEditingController>> _bankAccounts = [
    {"name": TextEditingController(), "number": TextEditingController()},
  ];

  // Step 5: Categories
  final List<String> _allCategories = [
    "Marketing",
    "Server Cost",
    "Office Rent",
    "Legal",
    "Software",
    "Hardware",
    "Travel",
    "Meals",
    "Contractors",
  ];
  final Set<String> _selectedCategories = {};

  // Step 6: Team
  final List<Map<String, dynamic>> _teams = [
    {"name": "Engineering", "members": []},
    {"name": "Marketing", "members": []},
  ];
  final TextEditingController _teamController = TextEditingController();

  // --- METHODS ---

  @override
  void dispose() {
    _pageController.dispose();
    _ownerNameController.dispose();
    _companyNameController.dispose();
    _mobileController.dispose();
    _countryController.dispose();
    _addressController.dispose();
    _workDescController.dispose();
    _fundingController.dispose();
    _runwayController.dispose();
    _teamController.dispose();
    for (var acc in _bankAccounts) {
      acc["name"]?.dispose();
      acc["number"]?.dispose();
    }
    super.dispose();
  }

  void _addBankAccount() {
    setState(() {
      _bankAccounts.add({
        "name": TextEditingController(),
        "number": TextEditingController(),
      });
    });
  }

  void _removeBankAccount(int index) {
    if (_bankAccounts.length > 1) {
      setState(() {
        _bankAccounts.removeAt(index);
        // Clear potential errors for removed fields
        _errors.remove('bank_name_$index');
        _errors.remove('bank_num_$index');
      });
    }
  }

  // Helper to remove error when user types
  void _clearError(String key) {
    if (_errors.contains(key)) {
      setState(() => _errors.remove(key));
    }
  }

  // --- VALIDATION LOGIC ---
  bool _validateCurrentStep() {
    setState(() {
      _errors.clear();
    });

    bool isValid = true;

    switch (_currentPage) {
      case 0: // Identity
        if (_ownerNameController.text.trim().isEmpty) _errors.add('owner');
        if (_mobileController.text.trim().isEmpty) _errors.add('mobile');
        if (_countryController.text.trim().isEmpty) _errors.add('country');
        if (_companyNameController.text.trim().isEmpty) _errors.add('company');
        isValid = _errors.isEmpty;
        break;

      case 1: // Structure
        if (_selectedCompanyType == null) _errors.add('type');
        if (_workDescController.text.trim().isEmpty) _errors.add('work');
        if (_addressController.text.trim().isEmpty) _errors.add('address');
        isValid = _errors.isEmpty;
        break;

      case 2: // Financials
        if (_fundingController.text.trim().isEmpty) _errors.add('funding');
        if (_runwayController.text.trim().isEmpty) _errors.add('runway');
        isValid = _errors.isEmpty;
        break;

      case 3: // Bank
        for (var i = 0; i < _bankAccounts.length; i++) {
          if (_bankAccounts[i]["name"]!.text.trim().isEmpty) {
            _errors.add('bank_name_$i');
          }
          if (_bankAccounts[i]["number"]!.text.trim().isEmpty) {
            _errors.add('bank_num_$i');
          }
        }
        isValid = _errors.isEmpty;
        break;

      case 4: // Categories
        if (_selectedCategories.isEmpty) {
          _errors.add('categories');
          isValid = false;
        }
        break;

      case 5: // Team
        if (_teams.isEmpty) {
          _errors.add('teams');
          isValid = false;
        }
        break;
    }

    if (!isValid) {
      // Trigger a rebuild to activate the ShakeWidgets
      setState(() {});
      HapticFeedback.heavyImpact(); // Add physical feedback for errors
    }

    return isValid;
  }

  Future<void> createTeamsInTeamsCollection() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Create each team in the teams collection
      for (var team in _teams) {
        await FirebaseFirestore.instance.collection('teams').add({
          "uid": userId,
          "teamName": team["name"],
          "monthlyBudget": 0.0, // Default budget
          "color": "blue", // Default color
          "iconCodePoint": 0xe7fd, // Group icon
          "iconFontFamily": "MaterialIcons",
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }

      log("Teams created in teams collection successfully");
    } catch (e) {
      log('Error creating teams in teams collection: $e');
    }
  }

  Future<void> uploadCompanyData() async {
    try {
      final formattedBankAccounts = _bankAccounts.map((account) {
        return {
          "name": account["name"]!.text.trim(),
          "number": account["number"]!.text.trim(),
        };
      }).toList();
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Upload company data to companies collection
      await FirebaseFirestore.instance.collection('companies').doc(userId).set({
        "uid": FirebaseAuth.instance.currentUser!.uid,
        "Owner Name": _ownerNameController.text.trim(),
        "Mobile Number": _mobileController.text.trim(),
        "Country Location": _countryController.text.trim(),
        "Company Name": _companyNameController.text.trim(),
        "Company Type": _selectedCompanyType,
        "Company Work": _workDescController.text.trim(),
        "Company Address": _addressController.text.trim(),
        "Funding": _fundingController.text.trim(),
        "Runway": _runwayController.text.trim(),
        "Bank Accounts": formattedBankAccounts,
        "Categories": _selectedCategories.toList(),
        "Teams": _teams,
      });

      // Create teams in teams collection
      await createTeamsInTeamsCollection();

      // Set companySetup flag in users collection
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        "companySetup": true,
        "email": FirebaseAuth.instance.currentUser!.email,
        "createdAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      log("Company setup completed successfully");
    } catch (e) {
      log('Company setup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (page) {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _currentPage = page;
                        _errors.clear(); // Clear errors on page swipe
                      });
                    },
                    children: [
                      _buildStep1Identity(),
                      _buildStep2Legal(),
                      _buildStep3Financials(),
                      _buildStep4Bank(),
                      _buildStep5Categories(),
                      _buildStep6Team(),
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- PAGES ---

  Widget _buildStep1Identity() {
    return _buildPageContainer(
      title: "Identity",
      subtitle: "Let's start with the basics.",
      children: [
        _buildLabel("OWNER NAME"),
        _buildInputField(
          _ownerNameController,
          "Your Full Name",
          "owner",
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 32),
        _buildLabel("MOBILE NUMBER"),
        _buildInputField(
          _mobileController,
          "+1 234 567 8900",
          "mobile",
          isNumber: true,
          icon: Icons.phone_outlined,
        ),
        const SizedBox(height: 32),
        _buildLabel("COUNTRY LOCATION"),
        _buildInputField(
          _countryController,
          "United States",
          "country",
          icon: Icons.public,
        ),
        const SizedBox(height: 32),
        _buildLabel("COMPANY NAME"),
        _buildInputField(
          _companyNameController,
          "Startup Name",
          "company",
          icon: Icons.business,
        ),
      ],
    );
  }

  Widget _buildStep2Legal() {
    return _buildPageContainer(
      title: "Structure",
      subtitle: "Legal details and location.",
      children: [
        _buildLabel("COMPANY TYPE"),
        ShakeWidget(
          shake: _errors.contains('type'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: double.infinity),
            child: ShadSelect<String>(
              placeholder: Text(
                'Select company type',
                style: GoogleFonts.inter(
                  color: _errors.contains('type')
                      ? const Color(0xFFFF453A).withValues(alpha: 0.6)
                      : Colors.white60,
                  fontSize: 15,
                ),
              ),
              decoration: ShadDecoration(
                color: const Color(0xFF141416),
                border: ShadBorder.all(
                  color: _errors.contains('type')
                      ? const Color(0xFFFF453A)
                      : Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              options: [
                ...companyTypes.entries.map(
                  (e) => ShadOption(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
              selectedOptionBuilder: (context, value) => Text(
                companyTypes[value]!,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedCompanyType = value;
                  _clearError('type');
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildLabel("WHAT IS THE WORK?"),
        _buildTextArea(
          _workDescController,
          "e.g. SaaS Platform...",
          "work",
          icon: Icons.description_outlined,
        ),
        const SizedBox(height: 32),
        _buildLabel("REGISTERED ADDRESS"),
        _buildTextArea(
          _addressController,
          "Full Address...",
          "address",
          icon: Icons.location_on_outlined,
        ),
      ],
    );
  }

  Widget _buildStep3Financials() {
    return _buildPageContainer(
      title: "Runway",
      subtitle: "Current financial health.",
      children: [
        ShakeWidget(
          shake: _errors.contains('funding'),
          child: Center(
            child: Column(
              children: [
                Text(
                  "TOTAL FUNDS LEFT",
                  style: GoogleFonts.inter(
                    color: _errors.contains('funding')
                        ? const Color(0xFFFF453A)
                        : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                IntrinsicWidth(
                  child: TextField(
                    controller: _fundingController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => _clearError('funding'),
                    style: GoogleFonts.inter(
                      color: _errors.contains('funding')
                          ? const Color(0xFFFF453A)
                          : Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      prefixText: "₹ ",
                      prefixStyle: GoogleFonts.inter(
                        color: _errors.contains('funding')
                            ? const Color(0xFFFF453A)
                            : Colors.white70,
                        fontSize: 48,
                      ),
                      hintText: "0",
                      hintStyle: GoogleFonts.inter(
                        color: _errors.contains('funding')
                            ? const Color(0xFFFF453A).withValues(alpha: 0.4)
                            : Colors.white60,
                        fontSize: 48,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 60),
        _buildLabel("TARGET RUNWAY (MONTHS)"),
        _buildInputField(
          _runwayController,
          "e.g. 18",
          "runway",
          isNumber: true,
          icon: Icons.timeline,
        ),
      ],
    );
  }

  Widget _buildStep4Bank() {
    return _buildPageContainer(
      title: "Banking",
      subtitle: "Add source accounts for tracking.",
      children: [
        ...List.generate(_bankAccounts.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "ACCOUNT 0${index + 1}",
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (index > 0)
                      GestureDetector(
                        onTap: () => _removeBankAccount(index),
                        child: Text(
                          "REMOVE",
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF453A),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  _bankAccounts[index]["name"]!,
                  "Bank Name (e.g. HDFC)",
                  "bank_name_$index",
                  icon: Icons.account_balance_outlined,
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  _bankAccounts[index]["number"]!,
                  "Account Number",
                  "bank_num_$index",
                  isNumber: true,
                  icon: Icons.numbers,
                ),
              ],
            ),
          );
        }),

        // Add Button
        GestureDetector(
          onTap: _addBankAccount,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  "Add Another Account",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Categories() {
    final hasError = _errors.contains('categories');

    return _buildPageContainer(
      title: "Categories",
      subtitle: "What do you spend money on?",
      extraHeader: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.inter(
            color: hasError ? const Color(0xFFFF453A) : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          child: Row(
            children: [
              if (hasError) ...[
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF453A),
                  size: 14,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                hasError
                    ? "Please select at least one category"
                    : "Select all that apply",
              ),
            ],
          ),
        ),
      ),
      children: [
        ShakeWidget(
          shake: hasError,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _allCategories.map((cat) {
              final isSelected = _selectedCategories.contains(cat);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    isSelected
                        ? _selectedCategories.remove(cat)
                        : _selectedCategories.add(cat);
                    if (_selectedCategories.isNotEmpty) {
                      _clearError('categories');
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : (hasError
                                ? const Color(0xFFFF453A)
                                : Colors.white.withValues(alpha: 0.1)),
                    ),
                  ),
                  child: Text(
                    cat,
                    style: GoogleFonts.inter(
                      color: isSelected
                          ? Colors.black
                          : (hasError
                                ? const Color(0xFFFF453A)
                                : Colors.white70),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStep6Team() {
    final hasError = _errors.contains('teams');

    return _buildPageContainer(
      title: "Teams",
      subtitle: "Teams will be created automatically for your company.",
      extraHeader: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Default teams (Engineering, Marketing) will be created. You can add more teams after setup.",
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      children: [
        ..._teams.map((team) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group, color: Colors.white60, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        team["name"],
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${team["members"]?.length ?? 0} members",
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        ShakeWidget(
          shake: hasError,
          child: Row(
            children: [
              Expanded(
                child: _buildInputField(
                  _teamController,
                  "Add Team (e.g. Sales)",
                  "teams",
                  icon: Icons.group_add,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (_teamController.text.isNotEmpty) {
                    setState(() {
                      _teams.add({"name": _teamController.text, "members": []});
                      _teamController.clear();
                      _clearError('teams');
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: hasError ? const Color(0xFFFF453A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.arrow_upward,
                    color: hasError ? Colors.white : Colors.black,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalPages, (index) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: index <= _currentPage
                        ? Colors.white
                        : const Color(0xFF1F1F22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (_currentPage > 0)
                GestureDetector(
                  onTap: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141416),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                )
              else
                const SizedBox(height: 38),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageContainer({
    required String title,
    required String subtitle,
    required List<Widget> children,
    Widget? extraHeader,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 16,
              ), // MATCHES LABELS
            ),
            const SizedBox(height: 24),
            ?extraHeader,
            ...children,
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF09090B).withValues(alpha: 0.0),
            const Color(0xFF09090B),
          ],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isFinishing
              ? null
              : () async {
                  FocusScope.of(context).unfocus();

                  if (!_validateCurrentStep()) {
                    return; // Stop if validation fails (Shake animation handles feedback)
                  }

                  if (_currentPage < _totalPages - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    setState(() => _isFinishing = true);
                    await uploadCompanyData();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MainNavigationWrapper(),
                      ),
                      (route) => false,
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            disabledBackgroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _isFinishing
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : Text(
                  _currentPage == _totalPages - 1
                      ? "Finish Setup"
                      : "Next Step",
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white70, // MATCHES LOGIN LABELS
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // --- UPDATED TO MATCH LOGIN UI WITH ICONS AND PADDING ---
  Widget _buildInputField(
    TextEditingController controller,
    String hint,
    String errorKey, {
    bool isNumber = false,
    IconData? icon, // Optional Icon Parameter added
  }) {
    final hasError = _errors.contains(errorKey);

    return ShakeWidget(
      shake: hasError,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasError
                ? const Color(0xFFFF453A)
                : Colors.white.withValues(alpha: 0.1), // MATCHES LOGIN BORDER
          ),
        ),
        child: TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          onChanged: (_) => _clearError(errorKey),
          style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: hasError
                  ? const Color(0xFFFF453A).withValues(alpha: 0.6)
                  : Colors.white60,
              fontSize: 15,
            ),
            // Replicates the sleek icon from your Login page
            icon: icon != null
                ? Icon(
                    icon,
                    color: hasError ? const Color(0xFFFF453A) : Colors.white60,
                    size: 20,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
            ), // MATCHES LOGIN PADDING
          ),
        ),
      ),
    );
  }

  // --- UPDATED TO MATCH LOGIN UI WITH ICONS AND PADDING ---
  Widget _buildTextArea(
    TextEditingController controller,
    String hint,
    String errorKey, {
    IconData? icon,
  }) {
    final hasError = _errors.contains(errorKey);

    return ShakeWidget(
      shake: hasError,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasError
                ? const Color(0xFFFF453A)
                : Colors.white.withValues(alpha: 0.1), // MATCHES LOGIN BORDER
          ),
        ),
        child: TextField(
          controller: controller,
          maxLines: 3,
          onChanged: (_) => _clearError(errorKey),
          style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: hasError
                  ? const Color(0xFFFF453A).withValues(alpha: 0.6)
                  : Colors.white60,
              fontSize: 15,
            ),
            // Replicates the sleek icon from your Login page
            icon: icon != null
                ? Icon(
                    icon,
                    color: hasError ? const Color(0xFFFF453A) : Colors.white60,
                    size: 20,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
            ), // MATCHES LOGIN PADDING
          ),
        ),
      ),
    );
  }
}

// --- SHAKE ANIMATION WIDGET ---
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shake;

  const ShakeWidget({super.key, required this.child, required this.shake});

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
