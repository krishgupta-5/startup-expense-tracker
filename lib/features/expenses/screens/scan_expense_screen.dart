import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ScanExpenseScreen extends StatefulWidget {
  const ScanExpenseScreen({super.key});

  @override
  State<ScanExpenseScreen> createState() => _ScanExpenseScreenState();
}

class _ScanExpenseScreenState extends State<ScanExpenseScreen> {
  bool _isScanning = false;
  String _scannedResult = "";
  bool _flashOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Deep Matte Black
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. Header
              _buildHeader(context),

              // 2. Camera/Scanner Area
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Scanner Frame
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isScanning
                          ? _buildScanningView()
                          : _buildIdleView(),
                    ),

                    const SizedBox(height: 40),

                    // Scan Button
                    if (!_isScanning) _buildScanButton(),
                  ],
                ),
              ),

              // 3. Bottom Actions
              if (_scannedResult.isNotEmpty) _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

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
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          Text(
            "Scan Expense",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Flash Toggle
          GestureDetector(
            onTap: () => setState(() => _flashOn = !_flashOn),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _flashOn
                    ? const Color(0xFF0A84FF)
                    : const Color(0xFF141416),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Icon(
                _flashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.qr_code_scanner,
          color: Colors.white.withValues(alpha: 0.3),
          size: 80,
        ),
        const SizedBox(height: 16),
        Text(
          "Position receipt within frame",
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Ensure good lighting for best results",
          style: GoogleFonts.inter(
            color: Colors.white24,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildScanningView() {
    return Stack(
      children: [
        // Animated scanning line
        AnimatedPositioned(
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOut,
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: const Color(0xFF0A84FF), width: 2),
              ),
            ),
          ),
        ),

        // Center crosshair
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: () => _startScanning(),
      child: Container(
        width: 200,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF0A84FF),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              "Start Scanning",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Scanned Result",
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _scannedResult,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _saveExpense(),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A84FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "Save Expense",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _retakeScan(),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141416),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "Retake",
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
    });

    // Simulate scanning process
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scannedResult =
              "Receipt scanned: Starbucks Coffee - ₹4.50\nDate: Nov 24, 2024\nCategory: Meals";
        });
      }
    });
  }

  void _saveExpense() {
    // Save expense logic here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF141416),
        content: Text(
          "Expense saved successfully",
          style: GoogleFonts.inter(color: Colors.white),
        ),
      ),
    );
    Navigator.pop(context);
  }

  void _retakeScan() {
    setState(() {
      _scannedResult = "";
      _isScanning = false;
    });
  }
}
