import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:exanor/services/store_owner_api_service.dart';

class IntelligenceUploadDialog extends StatefulWidget {
  final String storeId;
  const IntelligenceUploadDialog({super.key, required this.storeId});

  @override
  State<IntelligenceUploadDialog> createState() =>
      _IntelligenceUploadDialogState();
}

class _IntelligenceUploadDialogState extends State<IntelligenceUploadDialog>
    with SingleTickerProviderStateMixin {
  File? _selectedFile;
  bool _isAnalyzing = false;
  double _progress = 0.0;
  String _statusMessage = 'Uploading invoice...';
  late AnimationController _scannerController;
  Timer? _pollTimer;
  Timer? _progressTimer;
  int _pollCount = 0;

  static const int _pollIntervalFast = 3; // seconds
  static const int _pollIntervalSlow = 5; // seconds
  static const int _maxPollTimeSeconds = 120; // 2 min timeout

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _pollTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _cleanup() {
    _pollTimer?.cancel();
    _progressTimer?.cancel();
  }

  void _startFakeProgress() {
    _progress = 0.0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress = (_progress + 1.5).clamp(0.0, 90.0);
      });
    });
  }

  void _stopFakeProgress({double finalValue = 100.0}) {
    _progressTimer?.cancel();
    if (mounted) {
      setState(() => _progress = finalValue);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedFile = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error accessing camera: $e')));
      }
    }
  }

  Future<void> _analyzeWithAi() async {
    if (_selectedFile == null) return;

    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Uploading invoice...';
      _progress = 5.0;
    });
    _startFakeProgress();

    try {
      Position? position;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 5),
            );
          }
        }
      } catch (e) {
        debugPrint('Location warning: $e');
      }

      final lat = position?.latitude ?? 0.0;
      final lng = position?.longitude ?? 0.0;

      // ── Phase 1: Submit job ────────────────────────────────────────────
      final submitResult = await StoreOwnerApiService.submitPurchaseInvoice(
        widget.storeId,
        _selectedFile!,
        lat,
        lng,
      );

      debugPrint('[AI Upload] submitResult: $submitResult');

      // Old synchronous API fallback (status 200 with immediate result)
      if (submitResult['status'] == 200 &&
          submitResult['job_status'] == 'done') {
        _stopFakeProgress(finalValue: 100.0);
        if (mounted) {
          Navigator.pop(context, submitResult);
        }
        return;
      }

      if (submitResult['status'] != 202) {
        _stopFakeProgress(finalValue: 0.0);
        setState(() => _isAnalyzing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                submitResult['error'] ?? 'Failed to submit invoice',
              ),
            ),
          );
        }
        return;
      }

      final jobId = submitResult['job_id']?.toString();
      if (jobId == null || jobId.isEmpty) {
        _stopFakeProgress(finalValue: 0.0);
        setState(() => _isAnalyzing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid job ID from server')),
          );
        }
        return;
      }

      // ── Phase 2: Poll ──────────────────────────────────────────────────
      setState(() => _statusMessage = 'AI is analyzing your invoice...');

      // Hard timeout
      Timer(const Duration(seconds: _maxPollTimeSeconds), () {
        _cleanup();
        if (mounted && _isAnalyzing) {
          setState(() {
            _isAnalyzing = false;
            _progress = 0.0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Analysis timed out. Please try again.'),
            ),
          );
        }
      });

      _pollCount = 0;
      _schedulePoll(jobId);
    } catch (e) {
      _cleanup();
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Analysis failed: $e')));
      }
    }
  }

  void _schedulePoll(String jobId) {
    _pollCount++;
    final interval = _pollCount <= 3
        ? const Duration(seconds: _pollIntervalFast)
        : const Duration(seconds: _pollIntervalSlow);

    _pollTimer = Timer(interval, () => _poll(jobId));
  }

  Future<void> _poll(String jobId) async {
    if (!mounted || !_isAnalyzing) return;

    try {
      final data = await StoreOwnerApiService.pollPurchaseIntelligenceStatus(
        jobId,
      );

      debugPrint('[AI Poll] data: $data');

      if (!mounted) return;

      final jobStatus = data['job_status']?.toString();

      if (jobStatus == 'done') {
        _cleanup();
        _stopFakeProgress(finalValue: 100.0);
        setState(() => _statusMessage = 'Analysis complete!');
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          Navigator.pop(context, data);
        }
        return;
      }

      if (jobStatus == 'failed') {
        _cleanup();
        _stopFakeProgress(finalValue: 0.0);
        setState(() => _isAnalyzing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['error'] ?? 'AI analysis failed. Please try again.',
              ),
            ),
          );
        }
        return;
      }

      if (jobStatus == 'not_found') {
        _cleanup();
        _stopFakeProgress(finalValue: 0.0);
        setState(() => _isAnalyzing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job expired. Please re-upload the invoice.'),
            ),
          );
        }
        return;
      }

      // Still processing — schedule next poll
      _schedulePoll(jobId);
    } catch (e) {
      _cleanup();
      _stopFakeProgress(finalValue: 0.0);
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Network error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ─────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'AI POWERED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Invoice Scanner',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Upload an invoice and let AI extract the details.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Body ─────────────────────────────────────────
                Flexible(
                  child: _isAnalyzing
                      ? _buildAnalyzingState()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Steps
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStep(
                                    Icons.upload_file_rounded,
                                    'Upload',
                                  ),
                                  _buildStepConnector(),
                                  _buildStep(
                                    Icons.psychology_rounded,
                                    'AI Scan',
                                  ),
                                  _buildStepConnector(),
                                  _buildStep(
                                    Icons.check_circle_rounded,
                                    'Verify',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              // Upload zone
                              _buildUploadZone(),
                              const SizedBox(height: 18),
                              // Action buttons
                              _buildActionButtons(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildUploadZone() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _selectedFile != null
                ? const Color(0xFFEFF6FF)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _selectedFile != null
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFE2E8F0),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_selectedFile != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Color(0xFF2563EB),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _selectedFile!.path.split(RegExp(r'[/\\]')).last,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap to change file',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_rounded,
                    color: Color(0xFF3B82F6),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tap to Upload Invoice',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PDF, JPG, JPEG, PNG supported',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Camera button (full width, outlined)
        OutlinedButton.icon(
          onPressed: _takePhoto,
          icon: const Icon(Icons.camera_alt_rounded, size: 20),
          label: const Text(
            'Take a Photo',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: const Color(0xFF1E293B),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Analyze button (full width, filled)
        ElevatedButton.icon(
          onPressed: _selectedFile != null ? _analyzeWithAi : null,
          icon: const Icon(Icons.auto_awesome_rounded, size: 20),
          label: const Text(
            'Analyze with AI',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            disabledBackgroundColor: const Color(0xFFF1F5F9),
            disabledForegroundColor: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Pulsing AI icon
          SizedBox(
            width: 100,
            height: 100,
            child: AnimatedBuilder(
              animation: _scannerController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80 + (_scannerController.value * 20),
                      height: 80 + (_scannerController.value * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(
                          0xFF3B82F6,
                        ).withOpacity(0.15 - (_scannerController.value * 0.1)),
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF3B82F6),
                          width: 2.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        size: 36,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Extracting vendor details, products, and prices from your invoice.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          // Progress bar
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _progress / 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_progress.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Usually takes 15 – 30 seconds',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
