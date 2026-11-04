import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../application/face_liveness.dart';

/// «التحقق من الوجه» for a punch, «تسجيل الوجه» for enrolment: the front
/// camera, a live check, then the photos. Pops with a [FaceCapture], or null
/// when the employee closed it.
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key, required this.poses});

  final List<FacePose> poses;

  static Future<FaceCapture?> open(
    BuildContext context, {
    required List<FacePose> poses,
  }) => Navigator.of(context).push<FaceCapture>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FaceCaptureScreen(poses: poses),
    ),
  );

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  static const _timeLimit = Duration(seconds: 40);

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      minFaceSize: .2,
    ),
  );
  late final _liveness = FaceLiveness(poses: widget.poses);
  final _paths = <String>[];
  CameraController? _camera;
  Timer? _deadline;
  String _prompt = 'جارٍ تشغيل الكاميرا…';
  String? _failure;
  bool _working = false;
  bool _shooting = false;

  bool get _enrolling => widget.poses.length > 1;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    final camera = _camera;
    _camera = null;
    unawaited(_close(camera));
    unawaited(_detector.close());
    super.dispose();
  }

  Future<void> _close(CameraController? camera) async {
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } catch (_) {}
    await camera.dispose();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      final front = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.front)
          .firstOrNull;
      if (front == null) {
        return _unavailable('لا توجد كاميرا أمامية على هذا الجهاز');
      }
      final camera = CameraController(
        front,
        // 720p keeps each photo well under the server's 2MB.
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await camera.initialize();
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) return camera.dispose();
      setState(() => _camera = camera);
      await _watch();
    } on CameraException catch (error) {
      _unavailable(
        error.code.contains('Access')
            ? 'لم يُسمح للتطبيق باستخدام الكاميرا'
            : 'تعذّر تشغيل الكاميرا',
      );
    } catch (_) {
      _unavailable('تعذّر تشغيل الكاميرا');
    }
  }

  void _unavailable(String problem) {
    if (!mounted) return;
    // A punch goes on without the photo; enrolment cannot.
    if (!_enrolling) {
      Navigator.pop(context, FaceCapture.unavailable(problem));
    } else {
      setState(() => _failure = problem);
    }
  }

  Future<void> _watch() async {
    final camera = _camera;
    if (camera == null) return;
    _deadline?.cancel();
    _deadline = Timer(_timeLimit, () {
      if (mounted && !_liveness.done) _fail('انتهى الوقت قبل اكتمال التحقق');
    });
    await camera.startImageStream(_frame);
  }

  Future<void> _frame(CameraImage image) async {
    if (_working || _shooting || _failure != null) return;
    final camera = _camera;
    final input = camera == null ? null : _input(image, camera);
    if (input == null) return;
    _working = true;
    try {
      final faces = await _detector.processImage(input);
      if (!mounted || _shooting) return;
      final face = faces.length == 1 ? faces.first : null;
      // The stream is in the sensor's orientation; portrait swaps the sides.
      final frameWidth = image.width < image.height
          ? image.width
          : image.height;
      final step = _liveness.see(
        FaceFrame(
          faces: faces.length,
          trackingId: face?.trackingId,
          leftEyeOpen: face?.leftEyeOpenProbability,
          rightEyeOpen: face?.rightEyeOpenProbability,
          yaw: face?.headEulerAngleY,
          width: face == null ? 0 : face.boundingBox.width / frameWidth,
        ),
      );
      if (step.prompt != _prompt) setState(() => _prompt = step.prompt);
      final pose = step.shoot;
      if (pose != null) await _shoot(pose);
    } catch (error) {
      debugPrint('Face detection failed: $error');
    } finally {
      _working = false;
    }
  }

  Future<void> _shoot(FacePose pose) async {
    final camera = _camera;
    if (camera == null) return;
    _shooting = true;
    try {
      await camera.stopImageStream();
      final photo = await camera.takePicture();
      HapticFeedback.lightImpact();
      _paths.add(photo.path);
      _liveness.shot(pose);
      if (!mounted) return;
      if (_liveness.done) {
        _deadline?.cancel();
        Navigator.pop(context, FaceCapture(paths: _paths, livenessOk: true));
        return;
      }
      setState(() => _prompt = _liveness.prompt);
      _shooting = false;
      await camera.startImageStream(_frame);
    } catch (_) {
      _fail('تعذّر التقاط الصورة');
    } finally {
      _shooting = false;
    }
  }

  void _fail(String problem) {
    _deadline?.cancel();
    final camera = _camera;
    if (camera != null && camera.value.isStreamingImages) {
      unawaited(camera.stopImageStream().catchError((_) {}));
    }
    if (mounted) setState(() => _failure = problem);
  }

  Future<void> _retry() async {
    _liveness.reset();
    _paths.clear();
    setState(() {
      _failure = null;
      _prompt = 'ضع وجهك داخل الإطار';
    });
    if (_camera == null) {
      await _start();
    } else {
      await _watch();
    }
  }

  /// The stream frame as ML Kit reads it: NV21 on Android, BGRA on iOS.
  InputImage? _input(CameraImage image, CameraController camera) {
    // Capture is locked to portrait, so the sensor's own angle is the rotation.
    final rotation = InputImageRotationValue.fromRawValue(
      camera.description.sensorOrientation,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final camera = _camera;
    final photo = math.min(_paths.length + 1, widget.poses.length);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_enrolling ? 'تسجيل الوجه' : 'التحقق من الوجه'),
        leading: IconButton(
          tooltip: 'إغلاق',
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipOval(
                    child: camera == null || !camera.value.isInitialized
                        ? const ColoredBox(color: Color(0xFF1A1A1A))
                        : FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              // The preview is in the sensor's landscape size.
                              width: camera.value.previewSize!.height,
                              height: camera.value.previewSize!.width,
                              child: CameraPreview(camera),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: _failure == null
                  ? Column(
                      children: [
                        Text(
                          _prompt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _enrolling
                              ? 'الصورة $photo من ${widget.poses.length} · تُطابق على الخادم فقط'
                              : 'تُرسل صورة واحدة مع البصمة وتُطابق على الخادم',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xB8FFFFFF),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const Icon(
                          LucideIcons.scanFace,
                          size: 30,
                          color: AppTokens.warning,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _failure!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: tokens.brand,
                          ),
                          onPressed: _retry,
                          icon: const Icon(LucideIcons.refreshCw, size: 18),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
