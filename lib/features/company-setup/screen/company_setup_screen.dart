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

  // Validation State for Categories
  bool _showCategoryError = false;

  // --- CONTROLLERS & STATE ---

  // Step 1: Identity
  final _ownerNameController = TextEditingController();
  final _companyNameController = TextEditingController();

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
  final List<String> _departments = ["Engineering", "Marketing"];
  final TextEditingController _deptController = TextEditingController();

  // --- METHODS ---

  @override
  void dispose() {
    _pageController.dispose();
    _ownerNameController.dispose();
    _companyNameController.dispose();
    _addressController.dispose();
    _workDescController.dispose();
    _fundingController.dispose();
    _runwayController.dispose();
    _deptController.dispose();
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
      });
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
        "Company Name": _companyNameController.text.trim(),
        "Company Type": _selectedCompanyType,
        "Company Work": _workDescController.text.trim(),
        "Company Address": _addressController.text.trim(),
        "Funding": _fundingController.text.trim(),
        "Runway": _runwayController.text.trim(),
        "Bank Accounts": formattedBankAccounts,
        "Categories": _selectedCategories.toList(),
        "Departments": _departments,
      });

      // Set companySetup flag in users collection
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        "companySetup": true,
        "email": FirebaseAuth.instance.currentUser!.email,
        "createdAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      log(
        "Company setup completed successfully - AuthWrapper will handle navigation",
      );
      // Force navigation by triggering a state change that AuthWrapper will detect
      log("Company setup completed successfully");
    } catch (e) {
      log('Company setup error: $e');
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
              // 1. Header (Progress + Back)
              _buildHeader(),

              // 2. Swipeable Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                      // Reset error when user swipes away
                      if (page != 4) _showCategoryError = false;
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

              // 3. Navigation Footer
              _buildFooter(),
            ],
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
        _buildInputField(_ownerNameController, "Your Full Name"),
        const SizedBox(height: 32),
        _buildLabel("COMPANY NAME"),
        _buildInputField(_companyNameController, "Startup Name"),
      ],
    );
  }

  Widget _buildStep2Legal() {
    return _buildPageContainer(
      title: "Structure",
      subtitle: "Legal details and location.",
      children: [
        _buildLabel("COMPANY TYPE"),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: ShadSelect<String>(
            placeholder: Text(
              'Select company type',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 16),
            ),
            options: [
              ...companyTypes.entries.map(
                (e) => ShadOption(value: e.key, child: Text(e.value)),
              ),
            ],
            selectedOptionBuilder: (context, value) => Text(
              companyTypes[value]!,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
            ),
            onChanged: (value) {
              setState(() {
                _selectedCompanyType = value;
              });
            },
          ),
        ),
        const SizedBox(height: 32),
        _buildLabel("WHAT IS THE WORK?"),
        _buildTextArea(_workDescController, "e.g. SaaS Platform..."),
        const SizedBox(height: 32),
        _buildLabel("REGISTERED ADDRESS"),
        _buildTextArea(_addressController, "Full Address..."),
      ],
    );
  }

  Widget _buildStep3Financials() {
    return _buildPageContainer(
      title: "Runway",
      subtitle: "Current financial health.",
      children: [
        Center(
          child: Column(
            children: [
              Text(
                "TOTAL FUNDS LEFT",
                style: GoogleFonts.inter(
                  color: Colors.white24,
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
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    prefixText: "₹ ",
                    prefixStyle: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 48,
                    ),
                    hintText: "0",
                    hintStyle: GoogleFonts.inter(color: Colors.white12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 60),
        _buildLabel("TARGET RUNWAY (MONTHS)"),
        _buildInputField(_runwayController, "e.g. 18", isNumber: true),
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
                        color: Colors.white24,
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
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  _bankAccounts[index]["number"]!,
                  "Account Number",
                  isNumber: true,
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
    return _buildPageContainer(
      title: "Categories",
      subtitle: "What do you spend money on?",
      extraHeader: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.inter(
            color: _showCategoryError
                ? const Color(0xFFFF453A)
                : Colors.white38, // Text turns RED on error
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          child: Row(
            children: [
              if (_showCategoryError) ...[
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF453A),
                  size: 14,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                _showCategoryError
                    ? "Please select at least one category"
                    : "Select all that apply",
              ),
            ],
          ),
        ),
      ),
      children: [
        Wrap(
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
                  // Hide error as soon as user selects something
                  if (_selectedCategories.isNotEmpty) {
                    _showCategoryError = false;
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
                  // BORDER LOGIC SIMPLIFIED: No red border on error, just standard selection
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStep6Team() {
    return _buildPageContainer(
      title: "Departments",
      subtitle: "Who spends the money?",
      children: [
        ..._departments.map(
          (dept) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dept,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _departments.remove(dept)),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInputField(_deptController, "Add Dept (e.g. Sales)"),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                if (_deptController.text.isNotEmpty) {
                  setState(() {
                    _departments.add(_deptController.text);
                    _deptController.clear();
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          ],
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
          // Segmented Progress Bar
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
          // Clean Navigation Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentPage > 0)
                GestureDetector(
                  onTap: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                )
              else
                const SizedBox(width: 24),

              if (_currentPage == 5)
                GestureDetector(
                  onTap: () {
                    // Skip Logic
                  },
                  child: Text(
                    "Skip",
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
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
                  // Validation for Categories
                  if (_currentPage == 4 && _selectedCategories.isEmpty) {
                    setState(() {
                      _showCategoryError = true;
                    });
                    return; // Stop navigation
                  }

                  // Validation passed or not required
                  setState(() => _showCategoryError = false);

                  if (_currentPage < _totalPages - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    // Prevent double taps
                    setState(() => _isFinishing = true);

                    // Finish Logic - Upload data and let AuthWrapper handle navigation
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            _currentPage == _totalPages - 1 ? "Finish Setup" : "Next Step",
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
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildTextArea(TextEditingController controller, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
