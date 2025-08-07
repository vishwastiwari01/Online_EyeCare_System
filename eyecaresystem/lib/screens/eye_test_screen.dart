import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import '../services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';

// Enum for the different stages of the comprehensive eye test
enum TestPhase {
  welcome,
  calibration,
  snellenChart,
  astigmatismAxis,
  astigmatismPower,
  refraction,
  finished,
}

class EyeTestScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const EyeTestScreen({super.key, required this.cameras});

  @override
  _EyeTestScreenState createState() => _EyeTestScreenState();
}

class _EyeTestScreenState extends State<EyeTestScreen> {
  TestPhase _testPhase = TestPhase.welcome;
  bool _testingLeftEye = true;
  
  // Stores the final results for both eyes
  Map<String, dynamic> _leftEyeResult = {};
  Map<String, dynamic> _rightEyeResult = {};

  // --- Test-specific state variables ---
  int _currentSnellenLine = 0;
  double _currentRefractionDiopter = 0.0;
  double _refractionStep = 2.0;
  int _astigmatismAxis = 90;
  double _astigmatismPower = 0.0;

  // Camera controller for calibration
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  final List<String> _snellenLines = ['E', 'F P', 'T O Z', 'L P E D', 'P E C F D', 'E D F C Z P'];

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      _initializeCamera(widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      ));
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    _cameraController = CameraController(cameraDescription, ResolutionPreset.medium);
    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // --- Core Test Logic ---

  void _processSnellenResult(bool couldRead) {
    if (couldRead && _currentSnellenLine < _snellenLines.length - 1) {
      setState(() => _currentSnellenLine++);
    } else {
      String acuity = '20/${(200 / pow(2, _currentSnellenLine)).round()}';
      if (_testingLeftEye) {
        _leftEyeResult['acuity'] = acuity;
      } else {
        _rightEyeResult['acuity'] = acuity;
      }
      _moveToNextPhase();
    }
  }

  void _processRefractionChoice(bool optionA_isClearer) {
    double change = optionA_isClearer ? -_refractionStep : _refractionStep;
    _currentRefractionDiopter += change;

    _refractionStep /= 2;

    if (_refractionStep < 0.25) {
      double finalPower = (_currentRefractionDiopter * 4).round() / 4.0;
      String condition = finalPower < -0.25 ? 'Myopia' : (finalPower > 0.25 ? 'Hypermetropia' : 'Normal');
      
      if (_testingLeftEye) {
        _leftEyeResult['power'] = finalPower;
        _leftEyeResult['condition'] = condition;
      } else {
        _rightEyeResult['power'] = finalPower;
        _rightEyeResult['condition'] = condition;
      }
      _moveToNextPhase();
    } else {
      setState(() {});
    }
  }
  
  void _processAstigmatismAxis(int angle) {
      _astigmatismAxis = angle;
      if(_testingLeftEye) _leftEyeResult['astigmatism_axis'] = angle;
      else _rightEyeResult['astigmatism_axis'] = angle;
      _moveToNextPhase();
  }

  void _processAstigmatismPower(bool horizontalIsClearer) {
      _astigmatismPower += horizontalIsClearer ? -0.25 : 0.25;
      if(_astigmatismPower.abs() > 4.0) { // Limit the power
        _finalizeAstigmatismPower();
      } else {
        setState((){});
      }
  }

  void _finalizeAstigmatismPower() {
      if(_testingLeftEye) _leftEyeResult['astigmatism_power'] = _astigmatismPower;
      else _rightEyeResult['astigmatism_power'] = _astigmatismPower;
      _moveToNextPhase();
  }


  // --- Test Flow Management ---

  void _startEyeTest() {
    setState(() {
      _testingLeftEye = true;
      _leftEyeResult = {};
      _rightEyeResult = {};
      _resetTestStates();
      _testPhase = TestPhase.snellenChart;
    });
  }

  void _resetTestStates() {
    _currentSnellenLine = 0;
    _currentRefractionDiopter = 0.0;
    _refractionStep = 2.0;
    _astigmatismAxis = 90;
    _astigmatismPower = 0.0;
  }

  void _moveToNextPhase() {
    setState(() {
      switch (_testPhase) {
        case TestPhase.welcome:
          _testPhase = TestPhase.calibration;
          break;
        case TestPhase.calibration:
          _startEyeTest();
          break;
        case TestPhase.snellenChart:
          _testPhase = TestPhase.astigmatismAxis;
          break;
        case TestPhase.astigmatismAxis:
           _testPhase = TestPhase.astigmatismPower;
           break;
        case TestPhase.astigmatismPower:
          _testPhase = TestPhase.refraction;
          break;
        case TestPhase.refraction:
          if (_testingLeftEye) {
            _testingLeftEye = false;
            _resetTestStates();
            _testPhase = TestPhase.snellenChart;
          } else {
            _testPhase = TestPhase.finished;
            _saveFinalResults();
          }
          break;
        case TestPhase.finished:
          break;
      }
    });
  }
  
  Future<void> _saveFinalResults() async {
    final resultData = {
      'left_eye_acuity': _leftEyeResult['acuity'] ?? 'N/A',
      'right_eye_acuity': _rightEyeResult['acuity'] ?? 'N/A',
      'left_eye_power': _leftEyeResult['power'] ?? 0.0,
      'right_eye_power': _rightEyeResult['power'] ?? 0.0,
      'left_eye_condition': _leftEyeResult['condition'] ?? 'Unknown',
      'right_eye_condition': _rightEyeResult['condition'] ?? 'Unknown',
    };
    await ApiService.saveTestResult(resultData);
  }

  // --- UI Build Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("ClearView Eye Test", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildCurrentPhaseUI(),
      ),
    );
  }

  Widget _buildCurrentPhaseUI() {
    switch (_testPhase) {
      case TestPhase.welcome:
        return _buildWelcomeUI();
      case TestPhase.calibration:
        return _buildCalibrationUI();
      case TestPhase.snellenChart:
        return _buildSnellenChartUI();
      case TestPhase.astigmatismAxis:
        return _buildAstigmatismAxisUI();
      case TestPhase.astigmatismPower:
        return _buildAstigmatismPowerUI();
      case TestPhase.refraction:
        return _buildRefractionUI();
      case TestPhase.finished:
        return _buildFinishedUI();
    }
  }

  Widget _buildWelcomeUI() {
    return Padding(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.visibility, color: Colors.teal, size: 80),
          const SizedBox(height: 24),
          Text(
            "Comprehensive Vision Test",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            "This test will check your visual acuity, refractive error, and astigmatism. Please find a quiet, well-lit room.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _moveToNextPhase,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              textStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("Get Started"),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCalibrationUI() {
    return Padding(
      key: const ValueKey('calibration'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Text(
            "Distance Calibration",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            "Please cover your ${_testingLeftEye ? 'right' : 'left'} eye and stand back. Position your face inside the green box. Click 'Ready' when you are in position.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isCameraInitialized
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        CameraPreview(_cameraController!),
                        Container(
                          width: 200,
                          height: 280,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green, width: 4),
                            borderRadius: BorderRadius.circular(10)
                          ),
                        )
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _moveToNextPhase,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            child: const Text("Ready", style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildSnellenChartUI() {
    double fontSize = (MediaQuery.of(context).size.width * 0.8) / pow(2, _currentSnellenLine);
    
    return Column(
      key: const ValueKey('snellen'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Testing ${_testingLeftEye ? 'Left' : 'Right'} Eye: Visual Acuity", style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade700)),
        const SizedBox(height: 40),
        Expanded(
          child: Center(
            child: Text(
              _snellenLines[_currentSnellenLine],
              style: TextStyle(fontSize: min(150, fontSize), fontWeight: FontWeight.bold, letterSpacing: 8),
            ),
          ),
        ),
        Text("Can you read the letters above?", style: GoogleFonts.poppins(fontSize: 20)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(onPressed: () => _processSnellenResult(true), child: const Text("Yes")),
            ElevatedButton(onPressed: () => _processSnellenResult(false), child: const Text("No")),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }
  
  Widget _buildAstigmatismAxisUI() {
    return Column(
      key: const ValueKey('astig_axis'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Testing ${_testingLeftEye ? 'Left' : 'Right'} Eye: Astigmatism Axis", style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade700)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            "Which set of lines appears sharpest and darkest?",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 20),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: CustomPaint(
                painter: AstigmatismFanPainter(),
              ),
            ),
          ),
        ),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 8.0,
            runSpacing: 4.0,
            children: List.generate(6, (index) {
                int angle = (index + 1) * 30;
                return ElevatedButton(onPressed: () => _processAstigmatismAxis(angle), child: Text("$angle°"));
            }),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: () => _processAstigmatismAxis(0), child: const Text("All are equal")),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildAstigmatismPowerUI() {
    return Column(
      key: const ValueKey('astig_power'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Testing ${_testingLeftEye ? 'Left' : 'Right'} Eye: Astigmatism Power", style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade700)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            "Do the lines in the two blocks appear equally sharp?",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 20),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: CustomPaint(
                painter: AstigmatismBlockPainter(axis: _astigmatismAxis, power: _astigmatismPower),
              ),
            ),
          ),
        ),
        Text("Current Power: ${_astigmatismPower.toStringAsFixed(2)}", style: GoogleFonts.poppins(fontSize: 16)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(onPressed: () => _processAstigmatismPower(true), child: const Text("Horizontal is clearer")),
            ElevatedButton(onPressed: () => _processAstigmatismPower(false), child: const Text("Vertical is clearer")),
          ],
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: _finalizeAstigmatismPower, child: const Text("They are equal")),
        const SizedBox(height: 40),
      ],
    );
  }


  Widget _buildRefractionUI() {
    return Column(
      key: const ValueKey('refraction'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Testing ${_testingLeftEye ? 'Left' : 'Right'} Eye: Refractive Power", style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade700)),
        const SizedBox(height: 20),
        Text("Which option appears clearer?", style: GoogleFonts.poppins(fontSize: 22)),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRefractionOption("Option A", _currentRefractionDiopter - _refractionStep, () => _processRefractionChoice(true)),
            _buildRefractionOption("Option B", _currentRefractionDiopter + _refractionStep, () => _processRefractionChoice(false)),
          ],
        ),
         const SizedBox(height: 20),
        TextButton(onPressed: () => _moveToNextPhase(), child: const Text("They are equal / Both blurry")),
      ],
    );
  }

  Widget _buildRefractionOption(String title, double power, VoidCallback onPressed) {
    double blurAmount = power.abs() * 0.8; 
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 18)),
          const SizedBox(height: 10),
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
            child: Text(
              "E",
              style: GoogleFonts.roboto(fontSize: 100, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedUI() {
    return Padding(
      key: const ValueKey('finished'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
          const SizedBox(height: 24),
          Text("Test Complete!", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildResultCard("Left Eye", _leftEyeResult),
          const SizedBox(height: 16),
          _buildResultCard("Right Eye", _rightEyeResult),
          const SizedBox(height: 40),
          Text(
            "Disclaimer: This is a screening tool, not a medical diagnosis. Consult a professional optometrist for an accurate prescription.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(String title, Map<String, dynamic> result) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            Text("Visual Acuity: ${result['acuity'] ?? 'N/A'}", style: GoogleFonts.poppins(fontSize: 16)),
            Text("Estimated Power: ${result['power']?.toStringAsFixed(2) ?? 'N/A'} D", style: GoogleFonts.poppins(fontSize: 16)),
            Text("Astigmatism Axis: ${result['astigmatism_axis']?.toString() ?? 'N/A'}°", style: GoogleFonts.poppins(fontSize: 16)),
            Text("Astigmatism Power: ${result['astigmatism_power']?.toStringAsFixed(2) ?? 'N/A'} D", style: GoogleFonts.poppins(fontSize: 16)),
            Text("Condition: ${result['condition'] ?? 'N/A'}", style: GoogleFonts.poppins(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// Custom Painters for Astigmatism Test

class AstigmatismFanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 6;
      final x1 = center.dx + radius * cos(angle);
      final y1 = center.dy + radius * sin(angle);
      final x2 = center.dx - radius * cos(angle);
      final y2 = center.dy - radius * sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AstigmatismBlockPainter extends CustomPainter {
  final int axis;
  final double power;

  AstigmatismBlockPainter({required this.axis, required this.power});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final axisRadians = axis * pi / 180;

    final paint1 = Paint()..color = Colors.black..strokeWidth = 2;
    final paint2 = Paint()..color = Colors.black..strokeWidth = 2;
    
    // Simulate astigmatic blur by changing stroke width
    paint1.strokeWidth = max(1.0, 2.5 + power);
    paint2.strokeWidth = max(1.0, 2.5 - power);

    // Block 1 (Horizontal relative to axis)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(axisRadians);
    for(int i = -2; i <= 2; i++) {
        canvas.drawLine(Offset(-30, i * 8.0), Offset(30, i * 8.0), paint1);
    }
    canvas.restore();

    // Block 2 (Vertical relative to axis)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(axisRadians + pi/2);
     for(int i = -2; i <= 2; i++) {
        canvas.drawLine(Offset(-30, i * 8.0), Offset(30, i * 8.0), paint2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AstigmatismBlockPainter oldDelegate) {
    return oldDelegate.axis != axis || oldDelegate.power != power;
  }
}
