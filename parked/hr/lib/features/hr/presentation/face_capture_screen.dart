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
/// camera behind an oval frame, one step at a time ([FaceLiveness]). Each
/// photo is checked on the phone as soon as it is taken and retaken on the
/// spot when it is not clear, so the whole capture ends in one go. Pops with a
/// [FaceCapture], or null when the employee closed it.
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
  /// How long the ✓ after a good photo, or the reason a photo is retaken, stays.
  static const _pause = Duration(milliseconds: 800);

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      minFaceSize: .2,
    ),
  );
  late final _liveness = FaceLiveness(poses: widget.poses, strict: !_enrolling);
  final _clock = Stopwatch();
  final _paths = <String>[];
  CameraController? _camera;
  Timer? _deadline;
  String _prompt = 'جارٍ تشغيل الكاميرا…';
  String? _failure;
  bool _aligned = false;
  bool _confirmed = false;
  bool _working = false;
  bool _shooting = false;

  bool get _enrolling => widget.poses.length > 2;

  /// Three poses with a retake or two take longer than one action and a photo.
  Duration get _timeLimit =>
      _enrolling ? const Duration(seconds: 90) : const Duration(seconds: 40);

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
    _clock.start();
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
      // The stream is in the sensor's orientation; portrait swaps the sides.
      final step = _liveness.see(
        _frameOf(
          faces,
          width: math.min(image.width, image.height).toDouble(),
          height: math.max(image.width, image.height).toDouble(),
        ),
      );
      // A strict capture that started over drops the photos it had taken.
      if (_liveness.taken < _paths.length) {
        for (final path in _paths.sublist(_liveness.taken)) {
          unawaited(File(path).delete().then((_) {}, onError: (_) {}));
        }
        _paths.removeRange(_liveness.taken, _paths.length);
      }
      if (step.prompt != _prompt || step.aligned != _aligned) {
        setState(() {
          _prompt = step.prompt;
          _aligned = step.aligned;
        });
      }
      final pose = step.shoot;
      if (pose != null) await _shoot(pose);
    } catch (error) {
      debugPrint('Face detection failed: $error');
    } finally {
      _working = false;
    }
  }

  /// What liveness needs of the detected faces, in the upright frame.
  FaceFrame _frameOf(
    List<Face> faces, {
    required double width,
    required double height,
  }) {
    final face = faces.length == 1 ? faces.first : null;
    final box = face?.boundingBox;
    return FaceFrame(
      faces: faces.length,
      trackingId: face?.trackingId,
      leftEyeOpen: face?.leftEyeOpenProbability,
      rightEyeOpen: face?.rightEyeOpenProbability,
      yaw: face?.headEulerAngleY,
      width: box == null ? 0 : box.width / width,
      centerX: box == null ? .5 : box.center.dx / width,
      centerY: box == null ? .5 : box.center.dy / height,
      at: _clock.elapsed,
    );
  }

  Future<void> _shoot(FacePose pose) async {
    final camera = _camera;
    if (camera == null) return;
    _shooting = true;
    try {
      await camera.stopImageStream();
      final photo = await camera.takePicture();
      final problem = await _check(pose, photo.path);
      if (!mounted) return;
      if (problem != null) {
        unawaited(File(photo.path).delete().then((_) {}, onError: (_) {}));
        HapticFeedback.mediumImpact();
        _liveness.retake();
        setState(() {
          _prompt = problem;
          _aligned = false;
        });
      } else {
        HapticFeedback.lightImpact();
        _paths.add(photo.path);
        _liveness.shot(pose);
        setState(() {
          _confirmed = true;
          _prompt = 'تمام';
        });
      }
      await Future<void>.delayed(_pause);
      if (!mounted) return;
      if (_liveness.done) {
        _deadline?.cancel();
        Navigator.pop(
          context,
          FaceCapture(paths: _paths, livenessOk: true, poses: widget.poses),
        );
        return;
      }
      setState(() {
        _confirmed = false;
        _prompt = _liveness.prompt;
      });
      _shooting = false;
      await camera.startImageStream(_frame);
    } catch (_) {
      _fail('تعذّر التقاط الصورة');
    } finally {
      _shooting = false;
    }
  }

  /// The detector's reading of the still itself; a problem keeps the pose.
  Future<String?> _check(FacePose pose, String path) async {
    try {
      final faces = await _detector.processImage(InputImage.fromFilePath(path));
      final image = await decodeImageFromList(await File(path).readAsBytes());
      final width = math.min(image.width, image.height).toDouble();
      final height = math.max(image.width, image.height).toDouble();
      image.dispose();
      return FaceLiveness.problemWith(
        pose,
        _frameOf(faces, width: width, height: height),
      );
    } catch (error) {
      debugPrint('Face photo check failed: $error');
      return 'تعذّر فحص الصورة؛ أعدها';
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
    _clock
      ..stop()
      ..reset();
    setState(() {
      _failure = null;
      _aligned = false;
      _confirmed = false;
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
    final frameColor = _confirmed || _aligned
        ? AppTokens.success
        : Colors.white;
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (camera == null || !camera.value.isInitialized)
                          const ColoredBox(color: Color(0xFF1A1A1A))
                        else
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              // The preview is in the sensor's landscape size.
                              width: camera.value.previewSize!.height,
                              height: camera.value.previewSize!.width,
                              child: CameraPreview(camera),
                            ),
                          ),
                        CustomPaint(painter: _FaceFramePainter(frameColor)),
                        if (_confirmed)
                          const Center(
                            child: Icon(
                              LucideIcons.circleCheck,
                              size: 72,
                              color: AppTokens.success,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_enrolling)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Progress(
                  total: widget.poses.length,
                  taken: _liveness.taken,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
              child: _failure == null
                  ? Column(
                      children: [
                        Text(
                          _prompt,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _confirmed
                                ? AppTokens.success
                                : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _enrolling
                              ? 'الصورة ${math.min(_liveness.taken + 1, widget.poses.length)} من ${widget.poses.length} · تُطابق على الخادم فقط'
                              : 'تُرسل الصورتان مع البصمة ويتحقق منهما الخادم',
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

/// The oval the face goes in, the rest of the preview dimmed. White while the
/// face is out of place, green once it fits. It matches where [FaceLiveness]
/// wants the face: centred, about half the frame wide.
/// A head outline the face goes in: forehead, ears, jaw and chin. The dark
/// mask around it leaves only the face lit.
class _FaceFramePainter extends CustomPainter {
  const _FaceFramePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final face = _outline(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.width * .74,
        height: size.height * .68,
      ),
    );
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addPath(face, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(mask, Paint()..color = const Color(0x99000000));
    canvas.drawPath(
      face,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// The outline inside [box], drawn clockwise from the top of the head; the
  /// left half mirrors the right.
  static Path _outline(Rect box) {
    Offset at(double x, double y) =>
        Offset(box.left + box.width * x, box.top + box.height * y);
    void curve(Path path, List<double> p) {
      final a = at(p[0], p[1]), b = at(p[2], p[3]), c = at(p[4], p[5]);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }

    final start = at(.5, 0);
    final path = Path()..moveTo(start.dx, start.dy);
    curve(path, [.80, 0, .93, .14, .93, .36]); // forehead to temple
    curve(path, [1, .36, 1, .58, .92, .58]); // ear
    curve(path, [.91, .74, .80, .88, .66, .96]); // jaw
    curve(path, [.58, 1, .42, 1, .34, .96]); // chin
    curve(path, [.20, .88, .09, .74, .08, .58]);
    curve(path, [0, .58, 0, .36, .07, .36]);
    curve(path, [.07, .14, .20, 0, .5, 0]);
    return path..close();
  }

  @override
  bool shouldRepaint(_FaceFramePainter old) => old.color != color;
}

/// One dot per enrolment photo: filled once taken, outlined while waiting.
class _Progress extends StatelessWidget {
  const _Progress({required this.total, required this.taken});

  final int total;
  final int taken;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < total; i++)
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < taken ? AppTokens.success : Colors.transparent,
            border: Border.all(
              color: i < taken ? AppTokens.success : Colors.white70,
              width: 2,
            ),
          ),
        ),
    ],
  );
}
