import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart'; 
void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _cameraIndex = 0;
  bool _isDetectingFaces = false;
  FaceDetector? _faceDetector;
  List<Face> _faces = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    // Initialize the available cameras
    _cameras = await availableCameras();

    // Start with the first camera
    _startCamera(_cameraIndex);
  }

  void _startCamera(int cameraIndex) {
    if (_cameras == null || _cameras!.isEmpty) return;

    _cameraController = CameraController(
      _cameras![cameraIndex],
      ResolutionPreset.medium,
    );

    _cameraController!.initialize().then((_) {
      if (!mounted) return;
      _cameraController!.startImageStream((CameraImage image) {
        if (!_isDetectingFaces) {
          _isDetectingFaces = true;
          _detectFaces(image).then((_) {
            _isDetectingFaces = false;
          });
        }
      });
      setState(() {});
    });
  }

  Future<void> _detectFaces(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (var plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    // Set the image rotation based on your camera's orientation
    const InputImageRotation imageRotation = InputImageRotation.rotation0deg;

    // Specify the image format based on the CameraImage format
    const InputImageFormat inputImageFormat = InputImageFormat.nv21;

    // Assuming there's only one plane to get the bytesPerRow
    final int bytesPerRow = image.planes.first.bytesPerRow;

    // Create InputImageMetadata object
    final inputImageMetadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: bytesPerRow,
    );

    // Create InputImage object using fromBytes constructor
    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageMetadata, // Correct field for metadata
    );

    try {
      final List<Face> faces = await _faceDetector!.processImage(inputImage);
      setState(() {
        _faces = faces;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  void _switchCamera() {
    _cameraIndex = (_cameraIndex + 1) % _cameras!.length;
    _startCamera(_cameraIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Face Detection'),
          actions: [
            IconButton(
              icon: Icon(Icons.switch_camera),
              onPressed: _switchCamera,
            ),
          ],
        ),
        body: Stack(
          children: [
            CameraPreview(_cameraController!), // Camera preview
            if (_faces.isNotEmpty)
              ..._faces.map(
                (face) {
                  return Positioned(
                    left: face.boundingBox.left,
                    top: face.boundingBox.top,
                    width: face.boundingBox.width,
                    height: face.boundingBox.height,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                    ),
                  );
                },
              ).toList(),
          ],
        ),
      ),
    );
  }
}
