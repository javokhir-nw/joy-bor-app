import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';

// ── Result ───────────────────────────────────────────────────────────────────
class FaceVerificationResult {
  final bool skipped;
  final XFile? photo;
  const FaceVerificationResult({this.skipped = false, this.photo});
}

// ── Liveness steps ───────────────────────────────────────────────────────────
enum _Step { align, turnLeft, turnRight, moveCloser, blink, done }

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _ctrl;
  late final FaceDetector _detector;

  bool _processing = false;
  bool _advancing = false;
  _Step _step = _Step.align;
  bool _eyesWereOpen = false;

  // ── Init / Dispose ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // eye open probability
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initCamera();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _detector.close();
    super.dispose();
  }

  // ── Camera init ─────────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      _skip();
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _skip();
      return;
    }

    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final fmt = defaultTargetPlatform == TargetPlatform.android
        ? ImageFormatGroup.nv21
        : ImageFormatGroup.bgra8888;

    _ctrl = CameraController(
      front,
      ResolutionPreset.medium,
      imageFormatGroup: fmt,
      enableAudio: false,
    );

    await _ctrl!.initialize();
    if (!mounted) return;
    setState(() {});
    _ctrl!.startImageStream(_onImage);
  }

  // ── Image stream ────────────────────────────────────────────────────────────
  Future<void> _onImage(CameraImage img) async {
    if (_processing || _advancing || _step == _Step.done) return;
    _processing = true;
    try {
      final inputImg = _toInputImage(img);
      if (inputImg == null) return;
      final faces = await _detector.processImage(inputImg);
      if (!mounted || faces.isEmpty) return;
      await _evaluate(faces.first);
    } catch (_) {
      // ignore detection errors silently
    } finally {
      _processing = false;
    }
  }

  InputImage? _toInputImage(CameraImage img) {
    final desc = _ctrl?.description;
    if (desc == null) return null;

    final rotation =
        InputImageRotationValue.fromRawValue(desc.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(img.format.raw);
    if (format == null) return null;

    final Uint8List bytes;
    if (img.planes.length == 1) {
      bytes = img.planes[0].bytes;
    } else {
      final buf = WriteBuffer();
      for (final plane in img.planes) {
        buf.putUint8List(plane.bytes);
      }
      bytes = buf.done().buffer.asUint8List();
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(img.width.toDouble(), img.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: img.planes[0].bytesPerRow,
      ),
    );
  }

  // ── Step evaluation ─────────────────────────────────────────────────────────
  Future<void> _evaluate(Face face) async {
    bool pass = false;

    switch (_step) {
      case _Step.align:
        pass = face.boundingBox.width > 80;
      case _Step.turnLeft:
        pass = (face.headEulerAngleY ?? 0) > 15;  // front camera mirrored
      case _Step.turnRight:
        pass = (face.headEulerAngleY ?? 0) < -15; // front camera mirrored
      case _Step.moveCloser:
        pass = face.boundingBox.width > 140;
      case _Step.blink:
        final l = face.leftEyeOpenProbability ?? 1.0;
        final r = face.rightEyeOpenProbability ?? 1.0;
        if (!_eyesWereOpen && l > 0.7 && r > 0.7) _eyesWereOpen = true;
        pass = _eyesWereOpen && l < 0.3 && r < 0.3;
      case _Step.done:
        return;
    }

    if (pass) _advance();
  }

  // ── Advance to next step ────────────────────────────────────────────────────
  void _advance() {
    if (_advancing) return;
    _advancing = true;

    final next = _Step.values[_Step.values.indexOf(_step) + 1];
    setState(() {
      _step = next;
      _eyesWereOpen = false;
    });

    Future.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted) return;

      if (next == _Step.done) {
        try {
          if (_ctrl?.value.isStreamingImages == true) {
            await _ctrl!.stopImageStream();
          }
          final photo = await _ctrl!.takePicture();
          if (mounted) {
            Navigator.pop(context, FaceVerificationResult(photo: photo));
          }
        } catch (_) {
          _skip();
        }
        return;
      }

      _advancing = false;
    });
  }

  void _skip() {
    if (mounted) {
      Navigator.pop(context, const FaceVerificationResult(skipped: true));
    }
  }

  // ── UI helpers ──────────────────────────────────────────────────────────────
  static const _messages = <_Step, String>{
    _Step.align: 'Yuzingizni kameraga qarating',
    _Step.turnLeft: 'Boshingizni chapga buring',
    _Step.turnRight: "Boshingizni o'ngga buring",
    _Step.moveCloser: 'Kameraga yaqinroq keling',
    _Step.blink: "Ko'zingizni bir marta qising",
    _Step.done: 'Tasdiqlanmoqda...',
  };

  static const _icons = <_Step, IconData>{
    _Step.align: Icons.face_outlined,
    _Step.turnLeft: Icons.arrow_back_rounded,
    _Step.turnRight: Icons.arrow_forward_rounded,
    _Step.moveCloser: Icons.zoom_in_rounded,
    _Step.blink: Icons.remove_red_eye_outlined,
    _Step.done: Icons.check_circle_outline_rounded,
  };

  Color get _borderColor {
    if (_step == _Step.done || _advancing) return AppColors.success;
    return AppColors.primary;
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final totalDots = _Step.values.length - 1; // exclude done
    final currentIdx = _Step.values.indexOf(_step);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _skip,
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: AppColors.textPrimary),
                  ),
                  const Expanded(
                    child: Text(
                      'Yuz tekshiruvi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _skip,
                    child: const Text(
                      "O'tkazish",
                      style: TextStyle(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),

            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalDots, (i) {
                  final isDone = i < currentIdx;
                  final isActive = i == currentIdx;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.success
                          : isActive
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 28),

            // Circular camera preview
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _borderColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _borderColor.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _ctrl?.value.isInitialized == true
                      ? CameraPreview(_ctrl!)
                      : const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Step instruction
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Padding(
                key: ValueKey(_step),
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Icon(
                      _icons[_step],
                      color: _step == _Step.done
                          ? AppColors.success
                          : AppColors.primary,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _messages[_step] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Skip bottom link
            Padding(
              padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
              child: TextButton(
                onPressed: _skip,
                child: const Text(
                  'Keyinroq amalga oshiraman',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
