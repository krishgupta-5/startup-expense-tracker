import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../shared/widgets/custom_back_button.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

final List<Map<String, String>> _globalChatMessages = [];
Map<String, dynamic>? _globalCachedPayload;

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  bool _isDataLoaded = _globalCachedPayload != null;

  @override
  void initState() {
    super.initState();
    if (_globalChatMessages.isEmpty) {
      _globalChatMessages.add({
        'role': 'ai',
        'text':
            'Hello. I am your AI Financial Copilot. Ask me about your runway, burn rate, or specific expenses.',
      });
    }

    // Auto-scroll to bottom after rendering
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    if (_globalCachedPayload == null) {
      _fetchUserData();
    }
  }

  Map<String, dynamic> _cleanTimestamps(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Timestamp) {
        cleaned[entry.key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        cleaned[entry.key] = _cleanTimestamps(value);
      } else if (value is List) {
        cleaned[entry.key] = value.map((item) {
          if (item is Timestamp) return item.toDate().toIso8601String();
          if (item is Map<String, dynamic>) return _cleanTimestamps(item);
          return item;
        }).toList();
      } else {
        cleaned[entry.key] = value;
      }
    }
    return cleaned;
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final String uid = user.uid;

      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: uid)
          .orderBy('Date', descending: true)
          .limit(50)
          .get();

      final companySnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      final teamsSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('uid', isEqualTo: uid)
          .get();

      final membersSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('uid', isEqualTo: uid)
          .get();

      if (!mounted) return;

      final expenses = expensesSnapshot.docs.map((doc) => doc.data()).toList();
      final cleanExpenses = expenses.map((e) {
        return {
          "Amount": (e["Amount"] ?? 0).toDouble(),
          "Category": (e["Category"] ?? "unknown").toString(),
          "Type": (e["Type"] ?? "unknown").toString(),
          "Description": (e["Description"] ?? e["Title"] ?? "").toString(),
          "ExpenseType": (e["ExpenseType"] ?? "unknown").toString(),
        };
      }).toList();

      final companyData = companySnapshot.docs.isNotEmpty
          ? _cleanTimestamps(companySnapshot.docs.first.data())
          : {};
      final teamsData = teamsSnapshot.docs
          .map((doc) => _cleanTimestamps(doc.data()))
          .toList();
      final membersData = membersSnapshot.docs
          .map((doc) => _cleanTimestamps(doc.data()))
          .toList();

      _globalCachedPayload = {
        "expenses": cleanExpenses,
        "revenue": [],
        "company": companyData,
        "members": membersData,
        "teams": teamsData,
      };

      setState(() {
        _isDataLoaded = true;
      });
    } catch (e) {
      debugPrint("Error fetching data: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() {
      _globalChatMessages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      String baseUrl = Platform.isIOS
          ? "http://127.0.0.1:8000"
          : "http://10.0.2.2:8000";

      final requestBody = {
        "question": text,
        "sectionData": _globalCachedPayload ?? {},
        "history": _globalChatMessages
            .where((m) => m['role'] != 'error')
            .toList(),
      };

      final res = await http.post(
        Uri.parse("$baseUrl/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final responseText = data["response"] ?? "I couldn't process that.";

        setState(() {
          _globalChatMessages.add({'role': 'ai', 'text': responseText});
        });
      } else {
        setState(() {
          _globalChatMessages.add({
            'role': 'error',
            'text': 'Server error: ${res.statusCode}',
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _globalChatMessages.add({
            'role': 'error',
            'text': 'Connection failed.',
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Premium Solid Color Palette
    final bgColor = isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB);
    final cardColor = isDark
        ? const Color(0xFF141416)
        : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final shadowColor = isDark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.04);

    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF71717A);
    final accentColor = const Color(0xFF3B82F6); // Vibrant Blue

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // Ultra-Minimal Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomBackButton(),
                    Text(
                      "Copilot",
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 44), // Balances the back button
                  ],
                ),
              ),

              if (!_isDataLoaded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Syncing financial ledger...",
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _globalChatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _globalChatMessages[index];
                    final isUser = msg['role'] == 'user';
                    final isError = msg['role'] == 'error';

                    if (isUser) {
                      // User Message: High-contrast solid pill aligned right
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: textPrimary,
                            borderRadius: BorderRadius.circular(
                              24,
                            ).copyWith(bottomRight: const Radius.circular(6)),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: textPrimary.withValues(alpha: 0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Text(
                            msg['text'] ?? "",
                            style: GoogleFonts.inter(
                              color: bgColor, // Inverted for high contrast
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      );
                    } else {
                      // AI Message: Printed text style, no bubble, left aligned
                      return Container(
                        margin: const EdgeInsets.only(bottom: 32),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              child: Icon(
                                isError
                                    ? Icons.error_outline
                                    : Icons.auto_awesome,
                                color: isError
                                    ? const Color(0xFFFF453A)
                                    : accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                msg['text'] ?? "",
                                style: GoogleFonts.inter(
                                  color: isError
                                      ? const Color(0xFFFF453A)
                                      : textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  height:
                                      1.6, // High line-height for readability
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),

              if (_isTyping)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 24,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.auto_awesome,
                          color: accentColor.withValues(alpha: 0.5),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        "Analyzing...",
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Floating Command Line Input
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: borderColor),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: shadowColor,
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: GoogleFonts.inter(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: "Ask about your finances...",
                            hintStyle: GoogleFonts.inter(
                              color: textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: textPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: bgColor,
                            size: 20,
                          ),
                        ),
                      ),
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
}
