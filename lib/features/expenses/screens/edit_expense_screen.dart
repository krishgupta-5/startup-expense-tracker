import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../utils/data_helpers.dart';
import '../../../services/currency_preference_service.dart';
import '../../../services/currency_formatter.dart';
import '../../../services/bank_account_service.dart';

class EditExpenseScreen extends StatefulWidget {
  final String expenseId;
  final Map<String, dynamic> expenseData;

  const EditExpenseScreen({
    super.key,
    required this.expenseId,
    required this.expenseData,
  });

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  // 1. CONTROLLERS & STATE
  late TextEditingController _amountController;
  late TextEditingController _titleController;
  late TextEditingController _notesController;

  bool _isLoading = false;
  String _userCountryCode = '+1';
  bool _isLoadingCountry = true;

  // Attachment state
  String? _attachmentFileId;
  bool _isUploading = false;

  // Data Lists
  final categories = {
    'marketing': 'Marketing',
    'infrastructure': 'Infrastructure',
    'office': 'Office Rent',
    'software': 'Software',
    'hardware': 'Hardware',
    'transport': 'Transport',
    'design': 'Design',
    'travel': 'Travel',
    'meals': 'Meals',
    'contractors': 'Contractors',
    'legal': 'Legal',
    'others': 'Others',
  };
  final types = {
    'one_time': 'One-time',
    'recurring': 'Recurring',
    'subscription': 'Subscription',
  };

  // Bank account state
  Map<String, String> _bankAccounts = {};
  String? _selectedBankAccount;
  bool _isLoadingBanks = true;

  late String _selectedCategory;
  late String _selectedType;
  late DateTime _selectedDate;
  late TextEditingController _dateController; // Proper lifecycle controller

  // ✅ Upload file to Telegram
  Future<String?> uploadToTelegram(String filePath) async {
    try {
      await dotenv.load(fileName: ".env.local");
      final botToken = dotenv.env['TELEGRAM_BOT_TOKEN'];

      if (botToken == null) {
        throw Exception('Telegram bot token not found in environment');
      }

      final isImage =
          filePath.toLowerCase().endsWith('.jpg') ||
          filePath.toLowerCase().endsWith('.jpeg') ||
          filePath.toLowerCase().endsWith('.png') ||
          filePath.toLowerCase().endsWith('.gif');

      final uri = Uri.parse(
        "https://api.telegram.org/bot$botToken/${isImage ? 'sendPhoto' : 'sendDocument'}",
      );

      var request = http.MultipartRequest('POST', uri);
      request.fields['chat_id'] = '-1003885930746';

      if (isImage) {
        request.files.add(await http.MultipartFile.fromPath('photo', filePath));
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('document', filePath),
        );
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);

        if (isImage) {
          return data['result']['photo'].last['file_id'];
        } else {
          return data['result']['document']['file_id'];
        }
      } else {
        throw Exception("Upload failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('Error uploading to Telegram: $e');
      return null;
    }
  }

  // ✅ Upload file and update state
  Future<void> _uploadFile(String filePath, String fileName) async {
    try {
      setState(() => _isUploading = true);

      final fileId = await uploadToTelegram(filePath);

      if (fileId == null) {
        throw Exception('Failed to upload file to Telegram');
      }

      setState(() {
        _isUploading = false;
        _attachmentFileId = fileId;
      });

      _showMinimalToast("File uploaded successfully!");
    } catch (e) {
      debugPrint('Error uploading file: $e');
      setState(() => _isUploading = false);

      if (mounted) {
        _showMinimalToast("Failed to upload file: $e", isError: true);
      }
    }
  }

  // ✅ Check if file is an image by extension
  bool _isImageFile(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
  }

  // ✅ Get file icon based on file path
  IconData _getFileIcon(String? filePath) {
    if (filePath == null) return Icons.insert_drive_file;

    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
      case 'tar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  // ✅ Show file picker for adding attachments
  Future<void> _showFilePicker() async {
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF141416),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Attachment",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: Text(
                  "Take Photo",
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                  );
                  if (image != null) {
                    await _uploadFile(image.path, image.name);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: Text(
                  "Choose Photo / Video",
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final XFile? media = await picker.pickMedia();
                  if (media != null) {
                    await _uploadFile(media.path, media.name);
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.insert_drive_file,
                  color: Colors.white,
                ),
                title: Text(
                  "Choose PDF / Document",
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                subtitle: Text(
                  "PDF, Word, Excel, and more",
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: [
                      'pdf',
                      'doc',
                      'docx',
                      'xls',
                      'xlsx',
                      'txt',
                      'csv',
                    ],
                    allowMultiple: false,
                  );
                  if (result != null && result.files.single.path != null) {
                    await _uploadFile(
                      result.files.single.path!,
                      result.files.single.name,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open, color: Colors.white),
                title: Text(
                  "Any File",
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                subtitle: Text(
                  "Browse all file types",
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.any,
                    allowMultiple: false,
                  );
                  if (result != null && result.files.single.path != null) {
                    await _uploadFile(
                      result.files.single.path!,
                      result.files.single.name,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint("File pick error: $e");
      if (mounted) {
        _showMinimalToast("Could not open file picker.", isError: true);
      }
    }
  }

  void _loadUserCountryCode() {
    CurrencyPreferenceService.currencyNotifier.addListener(_onCurrencyChanged);
    _userCountryCode = CurrencyPreferenceService.getCurrencyPreferenceSync();
    setState(() => _isLoadingCountry = false);
  }

  @override
  void initState() {
    super.initState();
    _loadUserCountryCode();

    // 2. PRE-FILL DATA FROM FIREBASE
    _amountController = TextEditingController(
      text: widget.expenseData['Amount']?.toString() ?? "",
    );
    _titleController = TextEditingController(
      text: widget.expenseData['Title'] ?? "",
    );
    _notesController = TextEditingController(
      text: widget.expenseData['Description'] ?? "",
    );

    _attachmentFileId = widget.expenseData['AttachmentFileId'] as String?;

    String fetchedCategory =
        widget.expenseData['Category']?.toString().toLowerCase() ?? 'marketing';
    _selectedCategory = categories.containsKey(fetchedCategory)
        ? fetchedCategory
        : 'marketing';

    String fetchedType =
        widget.expenseData['Type']?.toString().toLowerCase() ?? 'one_time';
    _selectedType = types.containsKey(fetchedType) ? fetchedType : 'one_time';

    // Initialize date BEFORE the controller that references it
    if (widget.expenseData['Date'] is Timestamp) {
      _selectedDate = (widget.expenseData['Date'] as Timestamp).toDate();
    } else {
      _selectedDate = DateTime.now();
    }

    _dateController = TextEditingController(
      text: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
    );

    _fetchBankAccounts();
  }

  Future<void> _fetchBankAccounts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final companyId = userDoc.data()?['companyId'];
      if (companyId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (doc.exists && doc.data()!.containsKey('Bank Accounts')) {
        final accounts = doc.data()!['Bank Accounts'] as List<dynamic>;
        final Map<String, String> orderedBanks = {'Cash-': 'Cash'};
        for (var acc in accounts) {
          final String name =
              acc['name'] ?? acc['bankName'] ?? 'Unknown Bank';
          final String rawLast4 =
              acc['last4']?.toString() ?? acc['number']?.toString() ?? '';
          final String last4 = rawLast4.isNotEmpty
              ? BankAccountService.extractLast4(rawLast4)
              : '';
          final String key = '$name-$last4';
          final String label =
              last4.isNotEmpty ? '$name (****$last4)' : name;
          orderedBanks[key] = label;
        }
        if (mounted) {
          setState(() {
            _bankAccounts = orderedBanks;
            // Try to pre-select the bank that was saved with this expense
            final savedBank =
                widget.expenseData['BankAccount']?.toString() ?? '';
            _selectedBankAccount = _bankAccounts.containsKey(savedBank)
                ? savedBank
                : _bankAccounts.keys.first;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _bankAccounts = {'Cash-': 'Cash'};
            _selectedBankAccount = 'Cash-';
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load bank accounts: $e');
      if (mounted) {
        setState(() {
          _bankAccounts = {'Cash-': 'Cash'};
          _selectedBankAccount = 'Cash-';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingBanks = false);
    }
  }

  @override
  void dispose() {
    CurrencyPreferenceService.currencyNotifier.removeListener(
      _onCurrencyChanged,
    );
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _onCurrencyChanged() {
    if (mounted) {
      setState(() {
        _userCountryCode =
            CurrencyPreferenceService.getCurrencyPreferenceSync();
      });
    }
  }

  // --- UNIFIED MINIMAL TOAST ---
  void _showMinimalToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError
                  ? const Color(0xFFFF453A)
                  : const Color(0xFF30D158),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF141416),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        duration: const Duration(seconds: 3),
        elevation: 0,
      ),
    );
  }

  // 3. FIREBASE UPDATE LOGIC
  Future<void> _updateExpense() async {
    FocusScope.of(context).unfocus();

    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMinimalToast(
        "Please enter a valid amount greater than 0.",
        isError: true,
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showMinimalToast("Please enter a title.", isError: true);
      return;
    }

    if (_titleController.text.trim().length < 3) {
      _showMinimalToast(
        "Title must be at least 3 characters long.",
        isError: true,
      );
      return;
    }

    if (_titleController.text.trim().length > 50) {
      _showMinimalToast("Title must not exceed 50 characters.", isError: true);
      return;
    }

    if (_notesController.text.trim().isNotEmpty &&
        _notesController.text.trim().length > 500) {
      _showMinimalToast(
        "Description must not exceed 500 characters.",
        isError: true,
      );
      return;
    }

    if (_selectedDate.isAfter(DateTime.now())) {
      _showMinimalToast("Date cannot be in the future.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final companyId = userDoc.data()?['companyId'];
      if (companyId == null) throw Exception('Company not found');

      final double newAmount = double.tryParse(_amountController.text.trim())!;
      final double oldAmount = DataHelpers.safeParseDouble(
        widget.expenseData['Amount'],
      );
      final double diff = newAmount - oldAmount;

      final expenseType = widget.expenseData['ExpenseType'] as String?;
      final teamId = widget.expenseData['TeamId'] as String?;
      final teamMemberId = widget.expenseData['TeamMemberId'] as String?;

      if (diff != 0 && expenseType == 'member' && teamMemberId != null) {
        final memberDoc = await FirebaseFirestore.instance
            .collection('members')
            .doc(teamMemberId)
            .get();
        if (memberDoc.exists) {
          final data = memberDoc.data() as Map<String, dynamic>;
          final salary = (data['salary'] as num?)?.toDouble() ?? 0.0;
          final currentExpenses = (data['totalExpenses'] as num?)?.toDouble() ?? 0.0;
          final newMemberExpenses = currentExpenses + diff;
          if (newMemberExpenses > salary) {
            if (mounted) {
              _showMinimalToast(
                "Cannot update: Expense amount exceeds remaining salary for ${data['fullName'] ?? 'member'}",
                isError: true,
              );
              setState(() => _isLoading = false);
            }
            return;
          }
        }
      }

      final batch = FirebaseFirestore.instance.batch();

      final expenseRef = FirebaseFirestore.instance
          .collection('expenses')
          .doc(widget.expenseId);
      batch.update(expenseRef, {
        'Amount': newAmount,
        'Title': _titleController.text.trim(),
        'Description': _notesController.text.trim(),
        'Date': _selectedDate,
        'Category': _selectedCategory,
        'Type': _selectedType,
        'Time': FieldValue.serverTimestamp(),
        'AttachmentFileId': _attachmentFileId ?? '',
        if (_selectedBankAccount != null) 'BankAccount': _selectedBankAccount,
      });

      if (diff != 0) {
        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();
        double currentTotal = 0.0;
        if (companyDoc.exists) {
          currentTotal = DataHelpers.safeParseDouble(companyDoc.data()?['totalExpenses']);
        }
        double newTotal = currentTotal + diff;
        if (newTotal < 0) newTotal = 0.0;

        final companyRef = FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId);
        batch.update(companyRef, {"totalExpenses": newTotal});

        if (expenseType == 'team' && teamId != null) {
          final teamRef = FirebaseFirestore.instance.collection('teams').doc(teamId);
          batch.update(teamRef, {"usedBudget": FieldValue.increment(diff)});
        } else if (expenseType == 'member' && teamMemberId != null) {
          final memberRef = FirebaseFirestore.instance.collection('members').doc(teamMemberId);
          batch.update(memberRef, {
            "totalExpenses": FieldValue.increment(diff),
            "remainingSalary": FieldValue.increment(-diff),
          });
        }
      }

      await batch.commit();

      if (mounted) {
        _showMinimalToast("Expense updated successfully");
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        _showMinimalToast(
          e.message ?? 'Failed to update expense',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        Center(
                          child: Column(
                            children: [
                              _buildSectionLabel("AMOUNT"),
                              const SizedBox(height: 8),
                              _buildAmountInput(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        _buildSectionLabel('EXPENSE DETAILS'),
                        const SizedBox(height: 8),
                        _buildTextInput(
                          'Expense Title',
                          'e.g. Client Lunch',
                          _titleController,
                        ),

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: _buildSelectField(
                                label: 'Category',
                                currentValue: _selectedCategory,
                                items: categories,
                                icon: Icons.pie_chart_outline,
                                onChanged: (val) {
                                  FocusScope.of(context).unfocus();
                                  setState(() => _selectedCategory = val!);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSelectField(
                                label: 'Type',
                                currentValue: _selectedType,
                                items: types,
                                icon: Icons.repeat,
                                onChanged: (val) {
                                  FocusScope.of(context).unfocus();
                                  setState(() => _selectedType = val!);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        _buildDateSelector(),

                        const SizedBox(height: 24),

                        _buildTextArea('Description / Notes', _notesController),

                        const SizedBox(height: 32),

                        _buildSectionLabel('PAYMENT METHOD'),
                        const SizedBox(height: 8),
                        _buildBankSelector(),

                        const SizedBox(height: 32),

                        _buildSectionLabel('LINKED MEMBER (OPTIONAL)'),
                        const SizedBox(height: 16),
                        _buildLinkedMemberDisplay(),

                        const SizedBox(height: 32),

                        _buildSectionLabel("ATTACHMENT"),
                        const SizedBox(height: 16),
                        _buildExistingAttachment(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),

              _buildUpdateButton(),
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
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
          Text(
            "Edit Expense",
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

  Widget _buildAmountInput() {
    return Center(
      child: IntrinsicWidth(
        child: TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          onTapOutside: (event) => FocusScope.of(context).unfocus(),
          textInputAction: TextInputAction.next,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.w600,
            height: 1.0,
            letterSpacing: -2,
          ),
          cursorColor: const Color(0xFF30D158),
          decoration: InputDecoration(
            hintText: "0.00",
            hintStyle: GoogleFonts.inter(
              color: Colors.white12,
              fontSize: 56,
              fontWeight: FontWeight.w600,
              height: 1.0,
              letterSpacing: -2,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            prefixText: _isLoadingCountry
                ? '₹ '
                : "${CurrencyFormatter.getCurrencySymbol(_userCountryCode)} ",
            prefixStyle: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 56,
              fontWeight: FontWeight.w500,
              height: 1.0,
              letterSpacing: -2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextInput(
    String label,
    String placeholder,
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
        onTapOutside: (event) => FocusScope.of(context).unfocus(),
        textInputAction: TextInputAction.done,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
          hintText: placeholder,
          hintStyle: GoogleFonts.inter(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  Widget _buildSelectField({
    required String label,
    required String currentValue,
    required Map<String, String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: ShadSelect<String>(
            placeholder: Text(
              'Select $label',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
            ),
            initialValue: currentValue.isNotEmpty ? currentValue : null,
            options: [
              ...items.entries.map(
                (e) => ShadOption(value: e.key, child: Text(e.value)),
              ),
            ],
            selectedOptionBuilder: (context, value) => Text(
              items[value] ?? "Select",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('DATE'),
        const SizedBox(height: 8),
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
              hintText: 'Select date',
              labelText: 'Date',
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
            // Use the persistent _dateController — avoids creating a new
            // TextEditingController (and leaking it) on every build call.
            controller: _dateController,
            onTap: () {
              FocusScope.of(context).unfocus();
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Select Date",
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
                      selected: _selectedDate,
                      fromMonth: DateTime(_selectedDate.year - 1, 1),
                      toMonth: DateTime(_selectedDate.year + 1, 12),
                      onChanged: (DateTime? date) {
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                          });
                          // Update the persistent controller so the field reflects the new date
                          _dateController.text =
                              '${date.day}/${date.month}/${date.year}';
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextArea(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
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
            onTapOutside: (event) => FocusScope.of(context).unfocus(),
            textInputAction: TextInputAction.done,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText: "Enter details...",
              hintStyle: GoogleFonts.inter(color: Colors.white24),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // Shows the bank account selector (mirrors add_expense_screen behaviour)
  Widget _buildBankSelector() {
    if (_isLoadingBanks) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
          ),
        ),
      );
    }
    if (_bankAccounts.isEmpty) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Center(
          child: Text(
            'No payment methods available',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: double.infinity),
      child: ShadSelect<String>(
        placeholder: Text(
          'Select Payment Method',
          style: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
        ),
        initialValue: _selectedBankAccount,
        options: [
          ..._bankAccounts.entries.map(
            (e) => ShadOption(value: e.key, child: Text(e.value)),
          ),
        ],
        selectedOptionBuilder: (context, value) => Text(
          _bankAccounts[value] ?? 'Select',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onChanged: (val) {
          FocusScope.of(context).unfocus();
          setState(() => _selectedBankAccount = val);
        },
      ),
    );
  }

  // Shows the linked member/team name from the expense — read-only in edit
  Widget _buildLinkedMemberDisplay() {
    final teamMemberName =
        widget.expenseData['TeamMemberName'] as String?;
    final teamName = widget.expenseData['TeamName'] as String?;
    final linkedEntity = teamMemberName ?? teamName;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              linkedEntity != null && linkedEntity.isNotEmpty
                  ? linkedEntity
                  : 'No member/team linked',
              style: GoogleFonts.inter(
                color: linkedEntity != null && linkedEntity.isNotEmpty
                    ? Colors.white70
                    : Colors.white24,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (linkedEntity != null && linkedEntity.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                teamMemberName != null ? 'Member' : 'Team',
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExistingAttachment() {
    if (_attachmentFileId != null && _attachmentFileId!.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF30D158).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D158).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt,
                    color: Color(0xFF30D158),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Receipt attached",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF30D158),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "Stored in Telegram",
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isUploading ? Icons.hourglass_empty : Icons.close,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: _isUploading
                      ? null
                      : () async {
                          try {
                            setState(() => _isUploading = true);

                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              throw Exception('User not authenticated');
                            }

                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .get();

                            final companyId = userDoc.data()?['companyId'];
                            if (companyId == null) {
                              throw Exception('Company not found');
                            }

                            final batch = FirebaseFirestore.instance.batch();

                            final expenseRef = FirebaseFirestore.instance
                                .collection('expenses')
                                .doc(widget.expenseId);
                            batch.update(expenseRef, {
                              "AttachmentFileId": FieldValue.delete(),
                              "AttachmentFileName": FieldValue.delete(),
                              "AttachmentFilePath": FieldValue.delete(),
                            });

                            await batch.commit();

                            if (mounted) {
                              _showMinimalToast(
                                "Attachment removed successfully",
                              );
                              setState(() {
                                _isUploading = false;
                                _attachmentFileId = null;
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              _showMinimalToast(
                                "Failed to remove attachment",
                                isError: true,
                              );
                              setState(() => _isUploading = false);
                            }
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Receipt preview: show file-ID confirmation instead of empty box
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_done_outlined,
                      color: Color(0xFF30D158),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'File stored in Telegram',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // No attachment - show add attachment button
    return GestureDetector(
      onTap: _isUploading ? null : _showFilePicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.description,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "No receipt attached",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "Tap to upload",
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _isUploading
                  ? Icons.hourglass_empty
                  : Icons.add_photo_alternate_outlined,
              color: Colors.white54,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
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
          onPressed: _isLoading ? null : _updateExpense,
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
                  "Update Expense",
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
