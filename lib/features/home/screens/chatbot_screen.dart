import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

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
        'text': 'Hello! I am your AI Startup Assistant. Ask me anything about your runway, burn rate, or expenses.',
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
      final teamsData = teamsSnapshot.docs.map((doc) => _cleanTimestamps(doc.data())).toList();
      final membersData = membersSnapshot.docs.map((doc) => _cleanTimestamps(doc.data())).toList();

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
      String baseUrl = Platform.isIOS ? "http://127.0.0.1:8000" : "http://10.0.2.2:8000";
      
      final requestBody = {
        "question": text,
        "sectionData": _globalCachedPayload ?? {},
        "history": _globalChatMessages.where((m) => m['role'] != 'error').toList(),
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
          _globalChatMessages.add({'role': 'error', 'text': 'Server error: ${res.statusCode}'});
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _globalChatMessages.add({'role': 'error', 'text': 'Connection failed.'});
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF09090B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF09090B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF0A84FF), size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                "AI Assistant",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (!_isDataLoaded)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: const Color(0xFF141416),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Syncing your financial data...",
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  itemCount: _globalChatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _globalChatMessages[index];
                    final isUser = msg['role'] == 'user';
                    final isError = msg['role'] == 'error';

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isUser
                              ? const Color(0xFF0A84FF)
                              : isError
                                  ? const Color(0xFFFF453A).withValues(alpha: 0.1)
                                  : const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                            bottomLeft: !isUser ? const Radius.circular(4) : const Radius.circular(16),
                          ),
                          border: isUser
                              ? null
                              : Border.all(
                                  color: isError
                                      ? const Color(0xFFFF453A).withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Text(
                          msg['text'] ?? "",
                          style: GoogleFonts.inter(
                            color: isUser
                                ? Colors.white
                                : isError
                                    ? const Color(0xFFFF453A)
                                    : Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_isTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomLeft: const Radius.circular(4),
                          ),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0A84FF),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Thinking...",
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141416),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Ask about your startup's finances...",
                            hintStyle: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0A84FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
