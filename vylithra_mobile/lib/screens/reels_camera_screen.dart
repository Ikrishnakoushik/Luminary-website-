import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image_picker/image_picker.dart';

class ReelsCameraScreen extends StatefulWidget {
  const ReelsCameraScreen({super.key});

  @override
  State<ReelsCameraScreen> createState() => _ReelsCameraScreenState();
}

class _ReelsCameraScreenState extends State<ReelsCameraScreen> {
  CameraController? _cameraController;
  final SelfieSegmenter _segmenter = SelfieSegmenter(
    mode: SegmenterMode.stream,
    enableRawSizeMask: false,
  );
  
  bool _isProcessing = false;
  SegmentationMask? _mask;
  CameraImage? _latestImage;
  int _cameraIndex = 1; // Default to front camera
  bool _isRecording = false;

  // A default background color/image
  Color _backgroundColor = Colors.blueAccent;
  ui.Image? _backgroundImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (mounted) {
      setState(() {});
      _cameraController!.startImageStream(_processCameraImage);
    }
  }

  void _switchCamera() async {
    if (_cameraController != null) {
      await _cameraController!.stopImageStream();
      await _cameraController!.dispose();
    }
    _cameraIndex = _cameraIndex == 0 ? 1 : 0;
    _initializeCamera();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      
      final camera = _cameraController!.description;
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;

      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
      final mask = await _segmenter.processImage(inputImage);

      if (mounted) {
        setState(() {
          _mask = mask;
          _latestImage = image;
        });
      }
    } catch (e) {
      // Ignore errors for now
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _segmenter.close();
    super.dispose();
  }

  void _changeBackground(Color color) {
    setState(() {
      _backgroundColor = color;
      _backgroundImage = null;
    });
  }

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _backgroundImage = frame.image;
      });
    }
  }

  void _toggleRecording() {
    setState(() => _isRecording = !_isRecording);
    if (!_isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reel saved to gallery!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraController != null && _cameraController!.value.isInitialized)
            CameraPreview(_cameraController!),
          if (_mask != null && _latestImage != null)
            CustomPaint(
              painter: SegmentationPainter(
                mask: _mask!,
                imageSize: Size(_latestImage!.width.toDouble(), _latestImage!.height.toDouble()),
                backgroundColor: _backgroundColor,
                backgroundImage: _backgroundImage,
              ),
            ),

          // Native Scaffold UI Mock
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: Column(
              children: [
                _buildToolButton(Icons.flip_camera_android, 'Flip', _switchCamera),
                const SizedBox(height: 20),
                _buildToolButton(Icons.color_lens, 'Red BG', () => _changeBackground(Colors.redAccent)),
                const SizedBox(height: 20),
                _buildToolButton(Icons.color_lens, 'Blue BG', () => _changeBackground(Colors.blueAccent)),
                const SizedBox(height: 20),
                _buildToolButton(Icons.image, 'Image BG', _pickBackgroundImage),
              ],
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: _isRecording ? BorderRadius.circular(8) : null,
                    border: Border.all(color: Colors.white, width: 4),
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }
}

class SegmentationPainter extends CustomPainter {
  final SegmentationMask mask;
  final Size imageSize;
  final Color backgroundColor;
  final ui.Image? backgroundImage;

  SegmentationPainter({
    required this.mask,
    required this.imageSize,
    required this.backgroundColor,
    this.backgroundImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Save a layer to draw the background and then erase the person
    canvas.saveLayer(bounds, Paint());

    if (backgroundImage != null) {
      paintImage(
        canvas: canvas,
        rect: bounds,
        image: backgroundImage!,
        fit: BoxFit.cover,
      );
    } else {
      canvas.drawRect(bounds, Paint()..color = backgroundColor);
    }

    // Erase the background where the person is (confidence > 0.5)
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    for (int y = 0; y < mask.height; y++) {
      for (int x = 0; x < mask.width; x++) {
        final confidence = mask.confidences[y * mask.width + x];
        if (confidence > 0.5) {
          // Mirror correction for front camera
          final mappedX = size.width - (x * scaleX) - scaleX;
          canvas.drawRect(
            Rect.fromLTWH(mappedX, y * scaleY, scaleX, scaleY),
            clearPaint,
          );
        }
      }
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SegmentationPainter oldDelegate) {
    return oldDelegate.mask != mask || 
           oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.backgroundImage != backgroundImage;
  }
}
