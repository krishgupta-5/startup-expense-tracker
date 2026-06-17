import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AiScreen extends StatefulWidget {
  final String uid;

  const AiScreen({super.key, required this.uid});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen>
    with AutomaticKeepAliveClientMixin {
  final Map<String, bool> _sectionLoadStates = {};

  String aiInsight = "Loading AI insights...";
  Map<String, dynamic>? aiMetrics;

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

  // 🔥 UPDATED TO MATCH MAIN.PY ENDPOINT
  Future<void> fetchAIInsight() async {
    try {
      debugPrint("USER UID: ${widget.uid}");

      // Fetch expenses
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('uid', isEqualTo: widget.uid)
          .orderBy('Date', descending: true)
          .limit(50)
          .get();

      // Fetch company data
      final companySnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where('uid', isEqualTo: widget.uid)
          .limit(1)
          .get();

      // Fetch teams data
      final teamsSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('uid', isEqualTo: widget.uid)
          .get();

      // Fetch members data
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('uid', isEqualTo: widget.uid)
          .get();

      debugPrint(
        "DOCS FOUND - Expenses: ${expensesSnapshot.docs.length}, "
        "Company: ${companySnapshot.docs.length}, "
        "Teams: ${teamsSnapshot.docs.length}, "
        "Members: ${membersSnapshot.docs.length}",
      );

      if (!mounted) return;

      if (expensesSnapshot.docs.isEmpty) {
        setState(() {
          aiInsight =
              "No expenses recorded yet. Add some expenses to get AI insights!";
        });
        return;
      }

      // Prepare expenses data
      final expenses = expensesSnapshot.docs.map((doc) => doc.data()).toList();
      final cleanExpenses = expenses.map((e) {
        return {
          "Amount": (e["Amount"] ?? 0).toDouble(),
          "Category": (e["Category"] ?? "unknown").toString(),
          "Type": (e["Type"] ?? "unknown").toString(),
          "Description": (e["Description"] ?? e["Title"] ?? "").toString(),
          "linkedTeamName": (e["linkedTeamName"] ?? "general").toString(),
          "Date": (e["Date"] is Timestamp)
              ? (e["Date"] as Timestamp).toDate().toIso8601String()
              : e["Date"]?.toString() ?? "",
        };
      }).toList();

      // Prepare company data with Timestamp handling
      final companyData = companySnapshot.docs.isNotEmpty
          ? _cleanTimestamps(companySnapshot.docs.first.data())
          : {};

      // Prepare teams data with Timestamp handling
      final teamsData = teamsSnapshot.docs
          .map((doc) => _cleanTimestamps(doc.data()))
          .toList();

      // Prepare members data with Timestamp handling
      final membersData = membersSnapshot.docs
          .map((doc) => _cleanTimestamps(doc.data()))
          .toList();

      // Prepare request body according to main.py structure
      final requestBody = {
        "sectionName": "main",
        "sectionData": {
          "expenses": cleanExpenses,
          "revenue": [], // Add revenue collection if available
          "company": companyData,
          "members": membersData,
          "teams": teamsData,
        },
      };

      debugPrint("REQUEST BODY: ${jsonEncode(requestBody)}");

      // Determine URL based on platform
      String baseUrl;
      if (Platform.isIOS) {
        baseUrl = "http://127.0.0.1:8000";
      } else {
        baseUrl = "http://10.0.2.2:8000";
      }

      final res = await http.post(
        Uri.parse("$baseUrl/generate-ai-section"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      debugPrint("API RESPONSE: ${res.body}");

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          aiInsight = data["insight"] ?? "No insight generated";
          aiMetrics = data["metrics"] as Map<String, dynamic>?;
        });
      } else {
        setState(() {
          aiInsight = "Server error: ${res.statusCode}";
        });
      }
    } on SocketException {
      // AI server not running locally — show a friendly fallback
      if (!mounted) return;
      setState(() {
        aiInsight =
            "AI server is not running. Start the local Python server to get insights.";
      });
    } catch (e) {
      debugPrint("ERROR: $e");
      if (!mounted) return;
      setState(() {
        aiInsight = "Could not load AI insights. Please try again later.";
      });
    }
  }

  // Helper method to convert Timestamp objects to JSON-safe format
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
          if (item is Timestamp) {
            return item.toDate().toIso8601String();
          } else if (item is Map<String, dynamic>) {
            return _cleanTimestamps(item);
          }
          return item;
        }).toList();
      } else {
        cleaned[entry.key] = value;
      }
    }

    return cleaned;
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
                child: Column(
                  children: [
                    if (aiMetrics != null) _buildMetricsCard(),
                    _buildMainInsightCard(),
                  ],
                ),
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

  Widget _buildMetricsCard() {
    if (aiMetrics == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Key Financial Metrics",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            "Total Spending",
            "\$${(aiMetrics!['total_spending'] ?? 0).toStringAsFixed(0)}",
          ),
          _buildMetricRow(
            "Average Spending",
            "\$${(aiMetrics!['avg_spending'] ?? 0).toStringAsFixed(0)}",
          ),
          _buildMetricRow(
            "Net Burn Rate",
            "\$${(aiMetrics!['net_burn'] ?? 0).toStringAsFixed(0)}",
          ),
          _buildMetricRow("Risk Level", "${aiMetrics!['risk'] ?? 'Unknown'}"),
          if (aiMetrics!['funding'] != null)
            _buildMetricRow(
              "Total Funding",
              "\$${(aiMetrics!['funding']).toStringAsFixed(0)}",
            ),
          _buildMetricRow("Teams", "${aiMetrics!['team_count'] ?? 0}"),
          _buildMetricRow("Members", "${aiMetrics!['member_count'] ?? 0}"),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
