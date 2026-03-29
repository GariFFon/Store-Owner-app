import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';

class FaceRegistrationScreen extends StatefulWidget {
  final String staffId;
  final String staffName;

  const FaceRegistrationScreen({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isUploading = false;
  String _instructionText = "Align your face in the center";
  Timer? _instructionTimer;
  Timer? _recordingTimer;
  int _secondsElapsed = 0;

  final List<String> _instructions = [
    "Look Straight",
    "Turn Head Left",
    "Turn Head Right",
    "Look Up",
    "Look Down",
    "Look Straight",
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Find front camera
        final frontCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );

        _controller = CameraController(
          frontCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } else {
        _showError("No cameras found");
      }
    } catch (e) {
      _showError("Failed to initialize camera: $e");
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_controller!.value.isRecordingVideo) {
      return;
    }

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _secondsElapsed = 0;
        _instructionText = _instructions[0];
      });

      // Timer for instructions and auto-stop
      _instructionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _secondsElapsed++;
          if (_secondsElapsed < _instructions.length) {
            _instructionText = _instructions[_secondsElapsed];
          }
        });
      });

      _recordingTimer = Timer(const Duration(seconds: 6), () async {
        await _stopRecordingAndUpload();
      });
    } catch (e) {
      _showError("Failed to start recording: $e");
    }
  }

  Future<void> _stopRecordingAndUpload() async {
    _instructionTimer?.cancel();
    _recordingTimer?.cancel();

    if (_controller == null || !_controller!.value.isRecordingVideo) return;

    try {
      final XFile videoFile = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _isUploading = true;
        _instructionText = "Uploading...";
      });

      final File file = File(videoFile.path);
      final success = await StoreOwnerApiService.registerFace(
        widget.staffId,
        file,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Face registered successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          _showError("Failed to register face. Please try again.");
          setState(() {
            _instructionText = "Tap start to try again";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _instructionText = "Error occurred";
        });
        _showError("Error: $e");
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _instructionTimer?.cancel();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TranslatedText('Register Face for ${widget.staffName}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: _isCameraInitialized
                  ? CameraPreview(_controller!)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  _instructionText,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (!_isRecording && !_isUploading)
                  ElevatedButton.icon(
                    onPressed: _isCameraInitialized ? _startRecording : null,
                    icon: const Icon(Icons.videocam),
                    label: const TranslatedText("Start Recording"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  )
                else if (_isUploading)
                  const CircularProgressIndicator()
                else
                  // Recording in progress
                  Column(
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 10),
                      Text("Recording... $_secondsElapsed/6s"),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
