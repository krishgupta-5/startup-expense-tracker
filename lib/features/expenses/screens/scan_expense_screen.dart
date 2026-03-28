import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'add_expense_screen.dart';
import '../../../services/api_service.dart';
import '../../../services/currency_formatter.dart';

class ScanExpenseScreen extends StatefulWidget {
  const ScanExpenseScreen({super.key});

  @override
  State<ScanExpenseScreen> createState() => _ScanExpenseScreenState();
}

class _ScanExpenseScreenState extends State<ScanExpenseScreen>
    with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String _scanStatus = "Initializing...";
  String _scannedResult = "";
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  final ImagePicker _imagePicker = ImagePicker();
  late AnimationController _scanAnimController;
  Map<String, String> _parsedData = {};

  // NEW: Holds image path before processing so user can crop/retake
  String? _capturedImagePath;

  // Flash state
  bool _flashOn = false;

  // ✅ FIX: Loading locks and cost control
  bool _isProcessing = false;
  static const int _maxImageSizeMB =
      1; // Reduced to 1MB for better API performance

  @override
  void initState() {
    super.initState();
    _scanAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _initializeCamera();
  }

  @override
  void dispose() {
    _scanAnimController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // ─── CAMERA SETUP ──────────────────────────────────────────────────────────

  Future<void> _initializeCamera() async {
    try {
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        _showPermissionDialog();
        return;
      }
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _selectedCameraIndex = _cameras!.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
        if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;
        await _initializeCameraController();
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _initializeCameraController() async {
    if (_cameras == null || _cameras!.isEmpty) return;
    _cameraController = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141416),
        title: Text(
          'Camera Permission Required',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'Please grant camera permission to scan receipts.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF0A84FF)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeCamera();
            },
            child: Text(
              'Retry',
              style: GoogleFonts.inter(color: const Color(0xFF0A84FF)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFlash() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.setFlashMode(
          _flashOn ? FlashMode.off : FlashMode.torch,
        );
        setState(() => _flashOn = !_flashOn);
      } catch (e) {
        debugPrint('Error toggling flash: $e');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras != null && _cameras!.length > 1) {
      await _cameraController?.dispose();
      setState(() => _isCameraInitialized = false);
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
      await _initializeCameraController();
    }
  }

  // UPDATED: Now sets _capturedImagePath instead of processing immediately
  Future<void> _capturePhoto() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final XFile photo = await _cameraController!.takePicture();
        setState(() {
          _capturedImagePath = photo.path;
        });
      } catch (e) {
        debugPrint('Error capturing photo: $e');
      }
    }
  }

  // UPDATED: Now sets _capturedImagePath instead of processing immediately
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Slightly reduced quality for better performance
        maxWidth: 1200, // Limit initial image width
        maxHeight: 1200, // Limit initial image height
      );
      if (image != null) {
        setState(() {
          _capturedImagePath = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  // NEW: Crop Image Logic with compression
  Future<void> _cropImage() async {
    if (_capturedImagePath == null) return;
    try {
      // ✅ FIX: Check image size before processing
      final imageFile = File(_capturedImagePath!);
      final imageSizeBytes = await imageFile.length();
      final imageSizeMB = imageSizeBytes / (1024 * 1024);

      if (imageSizeMB > _maxImageSizeMB) {
        if (mounted) {
          _showErrorDialog(
            "Image too large",
            "Images larger than ${_maxImageSizeMB}MB are not supported to control costs. Please choose a smaller image.",
          );
          return;
        }
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: _capturedImagePath!,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Receipt',
            toolbarColor: const Color(0xFF09090B),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop Receipt'),
        ],
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 80, // Increased compression for better API performance
        maxWidth: 800, // Reduced max width for better mobile display
        maxHeight: 800, // Reduced max height for better mobile display
      );

      if (croppedFile != null) {
        setState(() {
          _capturedImagePath = croppedFile.path;
        });
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
    }
  }

  // NEW: Retake photo (cancel preview)
  void _cancelCapture() {
    setState(() {
      _capturedImagePath = null;
      _parsedData = {};
      _scannedResult = "";
    });
  }

  // ─── CORE: IMAGE → BASE64 → GEMINI VISION ──────────────────────────────────

  Future<void> _processScannedImage(String imagePath) async {
    // ✅ FIX: Add processing guard to prevent spam
    if (_isProcessing) return;

    setState(() {
      _isScanning = true;
      _isProcessing = true;
      _scanStatus = "Reading receipt...";
      _scannedResult = "";
    });
    _scanAnimController.repeat(reverse: true);

    try {
      // Read image and convert to base64
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final ext = imagePath.split('.').last.toLowerCase();
      final mediaType = ext == 'png' ? 'image/png' : 'image/jpeg';

      if (mounted) {
        setState(() => _scanStatus = "Extracting expense details...");
      }

      final result = await _extractWithGeminiVision(base64Image, mediaType);

      if (mounted) {
        setState(() {
          _isScanning = false;
          _parsedData = result;
          _scannedResult = _formatForDisplay(result);
        });
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scannedResult =
              "Error reading receipt. Please try again with better lighting.";
        });
      }
    } finally {
      _scanAnimController.stop();
      _scanAnimController.reset();
      setState(() => _isProcessing = false);
    }
  }

  Future<Map<String, String>> _extractWithGeminiVision(
    String base64Image,
    String mediaType,
  ) async {
    try {
      // ✅ FIX: Use ApiService with built-in retry and fallback
      final result = await ApiService.extractReceiptData(
        base64Image: base64Image,
        mediaType: mediaType,
      );

      return result;
    } catch (e) {
      debugPrint('Gemini Vision error: $e');
      return _emptyResult();
    }
  }

  // Helper method to return empty result
  Map<String, String> _emptyResult() => {
    'merchant': '',
    'amount': '',
    'date': '',
    'category': 'others',
    'description': '',
  };

  String _formatForDisplay(Map<String, String> data) {
    final hasData = data.values.any((v) => v.isNotEmpty);
    if (!hasData) {
      return 'Could not read receipt clearly.\nTap "Use This" to fill manually,\nor retake with better lighting.';
    }
    final lines = <String>[];
    if (data['merchant']?.isNotEmpty == true) {
      lines.add('🏪  ${data['merchant']}');
    }
    if (data['amount']?.isNotEmpty == true) {
      lines.add(
        '  ${CurrencyFormatter.getCurrencySymbol('+1')}${data['amount']}',
      );
    }
    if (data['date']?.isNotEmpty == true) {
      lines.add('📅  ${data['date']}');
    }
    if (data['category']?.isNotEmpty == true) {
      lines.add('🏷️  ${_capitalize(data['category']!)}');
    }
    if (data['description']?.isNotEmpty == true) {
      lines.add('📝  ${data['description']}');
    }
    return lines.join('\n');
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _navigateToAddExpense() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          prefillData: _parsedData,
          imagePath: _capturedImagePath, // Pass the captured image path
        ),
      ),
    );
  }

  void _retakeScan() {
    setState(() {
      _scannedResult = "";
      _parsedData = {};
      _isScanning = false;
      _capturedImagePath = null; // Also clear the captured image
    });
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Changed to solid black for full screen
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background View (Camera, Static Image, or Idle)
            if (_capturedImagePath != null)
              _buildImagePreview()
            else if (_isCameraInitialized)
              _buildCameraBackground()
            else
              _buildIdleView(),

            // 2. Scanning Overlay (Semi-transparent background when processing)
            if (_isScanning)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: _buildScanningView(),
              ),

            // 3. Header (Top Area)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(child: _buildHeader(context)),
            ),

            // 4. Bottom Actions (Camera Controls, Image Preview Controls, or Extracted Results)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: _scannedResult.isNotEmpty
                    ? _buildResultBottomPanel()
                    : _capturedImagePath != null && !_isScanning
                    ? _buildPreviewBottomControls()
                    : !_isScanning
                    ? _buildCameraBottomControls()
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Image.file(File(_capturedImagePath!), fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildCameraBackground() {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize!.height,
          height: _cameraController!.value.previewSize!.width,
          child: CameraPreview(_cameraController!),
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
                color: const Color(
                  0xFF141416,
                ).withValues(alpha: 0.8), // added slight transparency
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _capturedImagePath != null ? "Review Image" : "Scan Expense",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: _toggleFlash,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _flashOn
                    ? const Color(0xFF0A84FF)
                    : const Color(0xFF141416).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            color: Colors.white.withValues(alpha: 0.3),
            size: 72,
          ),
          const SizedBox(height: 16),
          Text(
            "Initializing camera...",
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Camera Bottom Controls (Gallery, Shutter, Flip)
  Widget _buildCameraBottomControls() {
    return Container(
      padding: const EdgeInsets.only(bottom: 30, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _roundBtn(Icons.photo_library, _pickImageFromGallery),
          GestureDetector(
            onTap: _capturePhoto,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0A84FF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 4,
                ),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          _roundBtn(Icons.flip_camera_ios, _switchCamera),
        ],
      ),
    );
  }

  // ✅ FIX: Helper method for error dialogs
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF141416),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("OK"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Preview Bottom Controls (Retake, Crop, Use Photo)
  Widget _buildPreviewBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFF141416).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Retake
          Expanded(
            child: GestureDetector(
              onTap: _cancelCapture,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Center(
                  child: Text(
                    "Retake",
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Crop
          GestureDetector(
            onTap: _cropImage,
            child: Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.crop, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          // Use This / Process
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_capturedImagePath != null) {
                  _processScannedImage(_capturedImagePath!);
                }
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "Use Photo",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF141416).withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.2),
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Color(0xFF0A84FF),
                  strokeWidth: 4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              _scanStatus,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Final Extracted Result View
  Widget _buildResultBottomPanel() {
    final bool hasData =
        _parsedData['merchant']?.isNotEmpty == true ||
        _parsedData['amount']?.isNotEmpty == true;

    return Container(
      constraints: const BoxConstraints(maxHeight: 350),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "EXTRACTED DATA",
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (hasData)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D158).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "✓ Parsed",
                    style: GoogleFonts.inter(
                      color: const Color(0xFF30D158),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  _scannedResult,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () async {
                    if (_isProcessing) {
                      _showErrorDialog(
                        "Processing in progress",
                        "Please wait for the current operation to complete.",
                      );
                      return;
                    }

                    setState(() => _isProcessing = true);

                    try {
                      _navigateToAddExpense();
                    } catch (e) {
                      _showErrorDialog("Navigation Error", e.toString());
                    } finally {
                      setState(() => _isProcessing = false);
                    }
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A84FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        "Proceed",
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
                  onTap: _retakeScan,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "Discard",
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 16,
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
}
