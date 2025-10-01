// lib/card_camera_screen.dart
// this is a test comment
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imgLib;
import 'package:path_provider/path_provider.dart';

class CardCameraScreen extends StatefulWidget {
  // Default to 3:4 baseball card ratio
  const CardCameraScreen({super.key, this.aspect = 3 / 4});
  final double aspect;


  @override
  State<CardCameraScreen> createState() => _CardCameraScreenState();
}

class _CardCameraScreenState extends State<CardCameraScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    final cams = await availableCameras();
    final cam = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );
    _controller = CameraController(
      cam,
      ResolutionPreset.max, // high quality for grading
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    await _controller!.setFlashMode(FlashMode.off);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ---------- Sharpness scoring ----------
  Future<double> _sharpnessScore(Uint8List bytes) async {
    final img = imgLib.decodeImage(bytes);
    if (img == null) return 0.0;
    final g = imgLib.grayscale(img);

    // Laplacian-like kernel
    const k = [
      [0, 1, 0],
      [1, -4, 1],
      [0, 1, 0],
    ];

    double sum = 0, sum2 = 0;
    int n = 0;

    for (int y = 1; y < g.height - 1; y += 2) {
      for (int x = 1; x < g.width - 1; x += 2) {
        double acc = 0;
        for (int j = -1; j <= 1; j++) {
          for (int i = -1; i <= 1; i++) {
            final p = g.getPixel(x + i, y + j);
            acc += imgLib.getLuminance(p) * k[j + 1][i + 1];
          }
        }
        final v = acc.toDouble();
        sum += v;
        sum2 += v * v;
        n++;
      }
    }
    if (n == 0) return 0.0;
    final mean = sum / n;
    final var_ = (sum2 / n) - mean * mean;
    return var_.abs();
  }

  // ---------- Burst capture (pick sharpest) ----------
  Future<XFile> _takeSmartPhoto(CameraController controller) async {
    final shots = <XFile>[];
    for (int i = 0; i < 3; i++) {
      final x = await controller.takePicture();
      shots.add(x);
      await Future.delayed(const Duration(milliseconds: 120));
    }

    double best = -1;
    XFile bestFile = shots.first;
    for (final x in shots) {
      final score = await _sharpnessScore(await x.readAsBytes());
      if (score > best) {
        best = score;
        bestFile = x;
      }
    }
    return bestFile;
  }

  Future<void> _shootAndReturn() async {
    if (_controller == null) return;

    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }

    final xfile = await _takeSmartPhoto(_controller!);
    final raw = File(xfile.path);

    // Auto-crop + enhance with the SAME heuristics used by the grader
    final processed = await preprocessAndAutocrop(raw, aspect: widget.aspect);

    if (!mounted) return;
    Navigator.pop<File?>(context, processed);
  }

  // ----- compute a size-aware 2.5:3.5 guide rect from the actual viewport -----
  Rect _calcGuideRect(Size viewport, double aspect) {
    final pad = 0.06 * math.min(viewport.width, viewport.height); // scale with screen
    final available = Rect.fromLTWH(
      pad,
      pad,
      viewport.width - pad * 2,
      viewport.height - pad * 2,
    );

    final availAspect = available.width / available.height;

    late Size size;
    if (availAspect > aspect) {
      // too wide, limit by height
      final h = available.height;
      final w = h * aspect;
      size = Size(w, h);
    } else {
      // too tall, limit by width
      final w = available.width;
      final h = w / aspect;
      size = Size(w, h);
    }

    final left = available.center.dx - size.width / 2;
    final top = available.center.dy - size.height / 2;
    return Rect.fromLTWH(left, top, size.width, size.height);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder(
          future: _initFuture,
          builder: (context, snap) {
            if (_controller == null || !_controller!.value.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }
            return Stack(
              children: [
                Positioned.fill(child: CameraPreview(_controller!)),

                // Size-aware guide overlay
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, constraints.maxHeight);
                      final guide = _calcGuideRect(size, widget.aspect);
                      return CustomPaint(
                        painter: _GuidePainter(
                          guide: guide,
                          borderRadius: 24,
                          strokeWidth: 3,
                          color: Colors.greenAccent,
                        ),
                      );
                    },
                  ),
                ),

                // Top controls
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(
                      _torch ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      if (_controller != null) {
                        _torch = !_torch;
                        await _controller!.setFlashMode(
                          _torch ? FlashMode.torch : FlashMode.off,
                        );
                        setState(() {});
                      }
                    },
                  ),
                ),

                // Bottom shutter
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        onPressed: _shootAndReturn,
                        backgroundColor: Colors.blue,
                        child: const Icon(Icons.camera),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ======================================================
// ========== Preprocess + auto-crop helpers ============
// ======================================================

Future<File> preprocessAndAutocrop(File rawFile, {double aspect = 3 / 4}) async {
  final bytes = await rawFile.readAsBytes();
  imgLib.Image? img = imgLib.decodeImage(bytes);
  if (img == null) return rawFile;

  // Downscale if needed
  const maxDim = 1400;
  final longSide = math.max(img.width, img.height);
  if (longSide > maxDim) {
    final s = maxDim / longSide;
    img = imgLib.copyResize(
      img,
      width: (img.width * s).round(),
      height: (img.height * s).round(),
      interpolation: imgLib.Interpolation.linear,
    );
  }

  // ✅ No cropping, no darkening, just save
  final dir = await getApplicationDocumentsDirectory();
  final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
  final outFile = File('${dir.path}/$filename');
  final outBytes = imgLib.encodeJpg(img, quality: 92);
  await outFile.writeAsBytes(outBytes, flush: true);

  print('✅ Saved raw-like image: ${outFile.path}');
  return outFile;
}



// ====== Heuristics reused from main.dart (identical logic) ======

_RectInt _estimateCardBounds(imgLib.Image img) {
  final gray = imgLib.grayscale(img);

  int left = _firstStrongVerticalEdge(gray, fromLeft: true);
  int right = gray.width - _firstStrongVerticalEdge(gray, fromLeft: false);
  int top = _firstStrongHorizontalEdge(gray, fromTop: true);
  int bottom = gray.height - _firstStrongHorizontalEdge(gray, fromTop: false);

  left = left.clamp(0, gray.width - 2);
  right = right.clamp(1, gray.width - 1);
  top = top.clamp(0, gray.height - 2);
  bottom = bottom.clamp(1, gray.height - 1);

  if (right - left < (gray.width * 0.3)) {
    left = (gray.width * 0.1).round();
    right = (gray.width * 0.9).round();
  }
  if (bottom - top < (gray.height * 0.3)) {
    top = (gray.height * 0.1).round();
    bottom = (gray.height * 0.9).round();
  }

  return _RectInt(left, top, right, bottom);
}

class _RectInt {
  final int left, top, right, bottom;
  _RectInt(this.left, this.top, this.right, this.bottom);
  int get width => right - left;
  int get height => bottom - top;
}

int _firstStrongVerticalEdge(imgLib.Image gray, {required bool fromLeft}) {
  final w = gray.width, h = gray.height;
  final y0 = (h * 0.35).round();
  final y1 = (h * 0.65).round();
  int bestX = fromLeft ? 1 : w - 2;
  double bestMag = -1;

  if (fromLeft) {
    for (int x = 1; x < w - 1; x++) {
      double sum = 0;
      for (int y = y0; y < y1; y++) {
        final g1 = gray.getPixel(x - 1, y);
        final g2 = gray.getPixel(x + 1, y);
        sum += (imgLib.getLuminance(g2) - imgLib.getLuminance(g1)).abs();
      }
      final mag = sum / (y1 - y0);
      if (mag > bestMag) {
        bestMag = mag;
        bestX = x;
      }
      if (bestMag > 25 && x > (w * 0.05)) break; // early-out
    }
  } else {
    for (int x = w - 2; x >= 1; x--) {
      double sum = 0;
      for (int y = y0; y < y1; y++) {
        final g1 = gray.getPixel(x - 1, y);
        final g2 = gray.getPixel(x + 1, y);
        sum += (imgLib.getLuminance(g2) - imgLib.getLuminance(g1)).abs();
      }
      final mag = sum / (y1 - y0);
      if (mag > bestMag) {
        bestMag = mag;
        bestX = x;
      }
      if (bestMag > 25 && x < (w * 0.95)) break; // early-out
    }
  }
  return bestX;
}

int _firstStrongHorizontalEdge(imgLib.Image gray, {required bool fromTop}) {
  final w = gray.width, h = gray.height;
  final x0 = (w * 0.35).round();
  final x1 = (w * 0.65).round();
  int bestY = fromTop ? 1 : h - 2;
  double bestMag = -1;

  if (fromTop) {
    for (int y = 1; y < h - 1; y++) {
      double sum = 0;
      for (int x = x0; x < x1; x++) {
        final g1 = gray.getPixel(x, y - 1);
        final g2 = gray.getPixel(x, y + 1);
        sum += (imgLib.getLuminance(g2) - imgLib.getLuminance(g1)).abs();
      }
      final mag = sum / (x1 - x0);
      if (mag > bestMag) {
        bestMag = mag;
        bestY = y;
      }
      if (bestMag > 25 && y > (h * 0.05)) break; // early-out
    }
  } else {
    for (int y = h - 2; y >= 1; y--) {
      double sum = 0;
      for (int x = x0; x < x1; x++) {
        final g1 = gray.getPixel(x, y - 1);
        final g2 = gray.getPixel(x, y + 1);
        sum += (imgLib.getLuminance(g2) - imgLib.getLuminance(g1)).abs();
      }
      final mag = sum / (x1 - x0);
      if (mag > bestMag) {
        bestMag = mag;
        bestY = y;
      }
      if (bestMag > 25 && y < (h * 0.95)) break; // early-out
    }
  }
  return bestY;
}

// ================= Guide painter =====================

class _GuidePainter extends CustomPainter {
  _GuidePainter({
    required this.guide,          // absolute pixels
    this.borderRadius = 20,
    this.strokeWidth = 3,
    this.color = Colors.white,
  });

  final Rect guide;
  final double borderRadius;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Darken everything outside the rounded guide rect
    final bg = Paint()..color = Colors.black.withOpacity(0.55);
    final clipPath = Path()
      ..addRRect(RRect.fromRectAndRadius(guide, Radius.circular(borderRadius)));
    final full = Path()..addRect(Offset.zero & size);
    final overlay = Path.combine(PathOperation.difference, full, clipPath);
    canvas.drawPath(overlay, bg);

    // Draw guide border
    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(
      RRect.fromRectAndRadius(guide, Radius.circular(borderRadius)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) {
    return old.guide != guide ||
        old.borderRadius != borderRadius ||
        old.strokeWidth != strokeWidth ||
        old.color != color;
  }
}
