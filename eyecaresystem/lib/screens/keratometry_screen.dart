import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart'; // Import ApiService

class KeratometryScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const KeratometryScreen({super.key, required this.cameras});

  @override
  _KeratometryScreenState createState() => _KeratometryScreenState();
}

class _KeratometryScreenState extends State<KeratometryScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isAnalyzing = false; // To show a loading indicator

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      final frontCamera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      );
      _initializeCamera(frontCamera);
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
    );
    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      print('Error initializing camera for Keratometry: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndAnalyze() async {
    if (!_isCameraInitialized || _isAnalyzing) return;

    setState(() => _isAnalyzing = true);

    try {
      // Capture the image
      final XFile image = await _cameraController!.takePicture();
      
      // Send the image for analysis
      final results = await ApiService.analyzeKeratometryImage(image);

      if (mounted) {
        // Show the results in a dialog
        _showAnalysisResults(results);
      }

    } catch (e) {
      print("Error during capture and analysis: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An error occurred."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _showAnalysisResults(Map<String, dynamic>? results) {
    if (results == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Analysis failed."), backgroundColor: Colors.red),
        );
        return;
    }

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text("Analysis Results"),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text("Rings Detected: ${results['rings_detected']}"),
                    const SizedBox(height: 8),
                    Text("Simulated K1 Reading: ${results['simulated_k1']} D"),
                    const SizedBox(height: 8),
                    Text("Simulated K2 Reading: ${results['simulated_k2']} D"),
                ],
            ),
            actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("OK"),
                )
            ],
        ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Keratometry Simulation", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF014D4E),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          if (_isCameraInitialized)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          
          CustomPaint(
            size: Size.infinite,
            painter: PlacidoDiskPainter(),
          ),

          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Text(
              "Align your eye in the center of the rings and hold steady.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                shadows: [const Shadow(blurRadius: 10.0, color: Colors.black)]
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            child: _isAnalyzing 
            ? const CircularProgressIndicator(color: Colors.white)
            : ElevatedButton(
              onPressed: _captureAndAnalyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF014D4E),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(24),
              ),
              child: const Icon(Icons.camera_alt, size: 40),
            ),
          )
        ],
      ),
    );
  }
}

class PlacidoDiskPainter extends CustomPainter {
  // ... existing PlacidoDiskPainter code ...
}
'''
