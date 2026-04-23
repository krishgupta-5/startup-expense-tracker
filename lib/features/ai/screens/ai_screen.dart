import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AiScreen extends StatefulWidget {
  final String uid; // 🔥 PASS USER ID

  const AiScreen({super.key, required this.uid});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen>
    with AutomaticKeepAliveClientMixin {
  final Map<String, bool> _sectionLoadStates = {};

  String aiInsight = "Loading AI insights...";

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeLoadStates();
    fetchAIInsight();
  }

  void _initializeLoadStates() {
    final sections = [
      'main',
      'keyPoints',
      'runway',
      'investment',
      'burn',
      'staffing',
      'performance',
      'team',
      'expense',
      'subscription',
    ];
    for (final section in sections) {
      _sectionLoadStates[section] = false;
    }
    _sectionLoadStates['main'] = true;
    _sectionLoadStates['keyPoints'] = true;
  }

  // 🔥 FINAL FIREBASE + AI FUNCTION
  Future<void> fetchAIInsight() async {
    if (widget.uid.isEmpty) {
      if (mounted) setState(() => aiInsight = "User not authenticated");
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Expenses')
          .where('uid', isEqualTo: widget.uid) // 🔥 USER FILTER
          .orderBy('Date', descending: true)
          .limit(10)
          .get();

      if (!mounted) return; // ✅ Early exit if disposed

      if (snapshot.docs.isEmpty) {
        setState(() {
          aiInsight = "No expense data found";
        });
        return;
      }

      final expenses = snapshot.docs.map((doc) => doc.data()).toList();

      // 🔥 CLEAN DATA (SAFE)
      final cleanExpenses = expenses.map((e) {
        return {
          "amount": (e["Amount"] ?? 0).toDouble(),
          "category": (e["Category"] ?? "unknown").toString(),
          "type": (e["Type"] ?? "unknown").toString(),
          "description": (e["Description"] ?? e["Title"] ?? "").toString(),
          "team": (e["linkedTeamName"] ?? "general").toString(),
        };
      }).toList();

      print("FINAL CLEAN EXPENSES: $cleanExpenses");

      final res = await http.post(
        Uri.parse("http://10.24.187.117:8000/expense-ai"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"expenses": cleanExpenses}),
      );

      print("API RESPONSE: ${res.body}");

      if (!mounted) return; // ✅ Check again after every await

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          aiInsight = data["insight"] ?? "No insight generated";
        });
      } else {
        setState(() {
          aiInsight = "Server error: ${res.statusCode}";
        });
      }
    } catch (e) {
      print("ERROR: $e");
      if (!mounted) return; // ✅
      setState(() {
        aiInsight = "Error: $e";
      });
    }
  }

  void _loadSection(String sectionKey) {
    if (!_sectionLoadStates[sectionKey]!) {
      if (mounted) {
        setState(() {
          _sectionLoadStates[sectionKey] = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(children: [_buildMainInsightCard()]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        "AI Financial Insights",
        style: GoogleFonts.inter(color: Colors.white),
      ),
    );
  }

  Widget _buildMainInsightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        aiInsight,
        style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
      ),
    );
  }
}
