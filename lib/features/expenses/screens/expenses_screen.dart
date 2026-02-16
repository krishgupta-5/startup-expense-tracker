// Required for FontFeature
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_expense_screen.dart';
import 'search_expense_screen.dart';
import 'expense_details_screen.dart';
import 'scan_expense_screen.dart';
import 'report_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (Minimal Text Only)
              _buildMinimalHeader(),

              const SizedBox(height: 32),

              // 2. Metrics (Flat Cards)
              SizedBox(
                height: 130,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  children: [
                    _buildFlatMetric(
                      "Budget Left",
                      "\$12,400",
                      "72%",
                      const Color(0xFF30D158),
                    ),
                    const SizedBox(width: 16),
                    _buildFlatMetric("Spent", "\$4,850", "+12%", Colors.white),
                    const SizedBox(width: 16),
                    _buildFlatMetric("Avg. Daily", "\$182", "-5%", Colors.grey),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 3. Actions (Outline Style)
              Text(
                "QUICK ACTIONS",
                style: GoogleFonts.inter(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildFlatActionGrid(context),

              const SizedBox(height: 40),

              // 5. Transactions (Clean List)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "TRANSACTIONS",
                    style: GoogleFonts.inter(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchExpenseScreen(),
                        ),
                      );
                    },
                    child: Text(
                      "VIEW ALL",
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFlatTransactionList(),

              const SizedBox(height: 80), // Bottom padding for navbar
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildMinimalHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "November",
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Expenses",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }

  Widget _buildFlatMetric(
    String label,
    String value,
    String badge,
    Color accent,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416), // Solid Matte Grey
        borderRadius: BorderRadius.circular(16),
        // No Shadow, just a barely visible border for definition
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Tiny dot indicator
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                badge,
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlatActionGrid(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
            );
          },
          child: _buildFlatActionButton("Add", Icons.add_rounded),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SearchExpenseScreen(),
              ),
            );
          },
          child: _buildFlatActionButton("Search", Icons.search_rounded),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ScanExpenseScreen(),
              ),
            );
          },
          child: _buildFlatActionButton("Scan", Icons.qr_code_rounded),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReportExpenseScreen(),
              ),
            );
          },
          child: _buildFlatActionButton(
            "Report",
            Icons.insert_chart_outlined_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildFlatActionButton(String label, IconData icon) {
    return Column(
      children: [
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFlatTransactionList() {
    final transactions = [
      {"title": "AWS Server", "cat": "Infrastructure", "amt": "240.00"},
      {"title": "Figma Pro", "cat": "Software", "amt": "45.00"},
      {"title": "WeWork", "cat": "Office", "amt": "850.00"},
      {"title": "Uber Business", "cat": "Transport", "amt": "24.50"},
      {"title": "Slack", "cat": "Communication", "amt": "12.00"},
    ];

    return Column(
      children: transactions.map((tx) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExpenseDetailsScreen(),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpenseDetailsScreen(),
                    ),
                  );
                },
                splashColor: Colors.white.withValues(alpha: 0.1),
                highlightColor: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    // Minimal Icon Placeholder (No container)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141416),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Info - Make entire row clickable
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx["title"]!,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tx["cat"]!,
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amount - Not clickable
                    Text(
                      "-\$${tx["amt"]}",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [
                          const FontFeature.tabularFigures(),
                        ], // Aligns numbers
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
