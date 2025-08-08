import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'package:camera/camera.dart';
import '../services/api_service.dart'; // Added for saving results

class EyeTestScreen extends StatefulWidget {
  // This now correctly receives the camera list from main.dart
  final List<CameraDescription> cameras;
  const EyeTestScreen({super.key, required this.cameras});

  @override
  _EyeTestScreenState createState() => _EyeTestScreenState();
}

enum TestPhase {
  welcome,
  nameInput,
  ageInput,
  distanceCalibration,
  snellenChart,
  refractionTest,
  duochromeTest,
  astigmatismTest,
  depthPerceptionTest,
  finished,
}

enum EyeCondition {
  myopia,
  hypermetropia,
  presbyopia,
  emmetropia,
  unknown,
}

class _EyeTestScreenState extends State<EyeTestScreen> {
  String _patientName = '';
  int _userAge = 30;
  TestPhase _testPhase = TestPhase.welcome;
  bool _testingLeftEye = true;

  int _currentSnellenLine = 0;
  final List<String> _snellenLines = [
    'E', 'F P', 'T O Z', 'L P E D', 'P E C F D',
    'E D F C Z P', 'F E L O P Z D', 'D E F P O T E C',
    'L E F O D P C T', 'F D P L T C O'
  ];
  String _leftEyeSnellenAcuity = 'N/A';
  String _rightEyeSnellenAcuity = 'N/A';

  double _currentDiopter = -1.0;
  double _stepSize = 0.5;
  static const double _minStepSize = 0.05;
  static const double _diopterToSigmaFactor = 3.0;
  double _leftEyePower = 0.0;
  double _rightEyePower = 0.0;
  EyeCondition _leftEyeCondition = EyeCondition.unknown;
  EyeCondition _rightEyeCondition = EyeCondition.unknown;

  bool _depthPerceptionPassed = false;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isAtCorrectDistance = false;

  @override
  void initState() {
    super.initState();
    // Correctly initialize camera using the passed list
    if (widget.cameras.isNotEmpty) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final frontCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    } on CameraException catch (e) {
      print('Camera Error: ${e.code}\n${e.description}');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  // --- NEW: Function to save the final results ---
  Future<void> _saveFinalResults() async {
    final resultData = {
      'left_eye_acuity': _leftEyeSnellenAcuity,
      'right_eye_acuity': _rightEyeSnellenAcuity,
      'left_eye_power': _leftEyePower,
      'right_eye_power': _rightEyePower,
      'left_eye_condition': _leftEyeCondition.toString().split('.').last,
      'right_eye_condition': _rightEyeCondition.toString().split('.').last,
    };
    bool success = await ApiService.saveTestResult(resultData);
    if(success) {
        print("Results saved to history successfully!");
    } else {
        print("Failed to save results to history.");
    }
  }


  void _startSnellenTest() {
    setState(() {
      _testPhase = TestPhase.snellenChart;
      _currentSnellenLine = 0;
    });
  }

  void _nextSnellenLine(bool canRead) {
    if (canRead) {
      if (_currentSnellenLine < _snellenLines.length - 1) {
        setState(() {
          _currentSnellenLine++;
        });
      } else {
        _finalizeSnellenTest(_snellenLines.length);
      }
    } else {
      _finalizeSnellenTest(_currentSnellenLine);
    }
  }

  String _getSnellenAcuity(int lastLineReadIndex) {
    if (lastLineReadIndex >= _snellenLines.length) return '20/20';
    if (lastLineReadIndex <= 0) return '20/200';
    final denominators = [200, 100, 70, 50, 40, 30, 25, 20, 15, 10];
    return '20/${denominators[lastLineReadIndex]}';
  }

  void _finalizeSnellenTest(int lastLineReadIndex) {
    final acuity = _getSnellenAcuity(lastLineReadIndex);
    setState(() {
      if (_testingLeftEye) {
        _leftEyeSnellenAcuity = acuity;
      } else {
        _rightEyeSnellenAcuity = acuity;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSnellenResultDialog();
    });
  }

  void _showSnellenResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(
          "${_testingLeftEye ? "Left" : "Right"} Eye Snellen Test Result",
        ),
        content: Text(
          "Estimated Visual Acuity: ${_testingLeftEye ? _leftEyeSnellenAcuity : _rightEyeSnellenAcuity}",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _testPhase = TestPhase.refractionTest;
                _currentDiopter = -1.0;
                _stepSize = 0.5;
              });
            },
            child: const Text("Start Refraction Test"),
          ),
        ],
      ),
    );
  }

  double _getBlurSigma(double diopter) {
    if (diopter >= 0) return 0.0;
    return diopter.abs() * _diopterToSigmaFactor;
  }

  List<double> _getOptions() {
    double optionA = _currentDiopter + _stepSize / 2;
    double optionB = _currentDiopter - _stepSize / 2;
    optionA = min(0.0, optionA);
    optionB = min(0.0, optionB);
    return [optionA, optionB];
  }

  void _processABRefractionChoice(int choice) {
    setState(() {
      final options = _getOptions();
      if (choice == 1) {
        _currentDiopter = options[0];
      } else if (choice == 2) {
        _currentDiopter = options[1];
      }
      _stepSize /= 2;
      if (_stepSize < _minStepSize) {
        _finalizeRefractionTest(_currentDiopter);
      }
    });
  }

  void _finalizeRefractionTest(double finalPower) {
    EyeCondition condition;
    if (finalPower < -0.25) {
      condition = EyeCondition.myopia;
    } else if (finalPower > 0.25) {
      if (_userAge >= 40 && finalPower > 0.75) {
        condition = EyeCondition.presbyopia;
      } else {
        condition = EyeCondition.hypermetropia;
      }
    } else {
      condition = EyeCondition.emmetropia;
    }

    setState(() {
      if (_testingLeftEye) {
        _leftEyePower = finalPower;
        _leftEyeCondition = condition;
      } else {
        _rightEyePower = finalPower;
        _rightEyeCondition = condition;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRefractionResultDialog();
    });
  }

  void _showRefractionResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(
          "${_testingLeftEye ? "Left" : "Right"} Eye Refraction Result",
        ),
        content: Text(
          "Estimated Lens Power: ${_testingLeftEye ? _leftEyePower.toStringAsFixed(2) : _rightEyePower.toStringAsFixed(2)} D\n"
          "Condition: ${_testingLeftEye ? _leftEyeCondition.toString().split('.').last.toUpperCase() : _rightEyeCondition.toString().split('.').last.toUpperCase()}",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (_testingLeftEye) {
                setState(() {
                  _testingLeftEye = false;
                  _testPhase = TestPhase.distanceCalibration;
                  _isAtCorrectDistance = false;
                });
              } else {
                _startDuochromeTest();
              }
            },
            child: Text(_testingLeftEye ? "Start Right Eye Test" : "Start Duochrome Test"),
          ),
        ],
      ),
    );
  }

  void _startDuochromeTest() {
    setState(() => _testPhase = TestPhase.duochromeTest);
  }

  void _handleDuochromeResult(String result) {
    _startAstigmatismTest();
  }

  void _startAstigmatismTest() {
    setState(() => _testPhase = TestPhase.astigmatismTest);
  }

  void _handleAstigmatismResult(String result) {
    _startDepthPerceptionTest();
  }

  void _startDepthPerceptionTest() {
    setState(() => _testPhase = TestPhase.depthPerceptionTest);
  }

  void _processDepthPerceptionChoice(bool choseCloser) {
    setState(() {
      _depthPerceptionPassed = choseCloser;
      _testPhase = TestPhase.finished;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOverallResult();
      _saveFinalResults(); // Save results when the test is fully complete
    });
  }

  void _moveToNextPhase() {
    setState(() {
      switch (_testPhase) {
        case TestPhase.welcome:
          _testPhase = TestPhase.nameInput;
          break;
        case TestPhase.nameInput:
          _testPhase = TestPhase.ageInput;
          break;
        case TestPhase.ageInput:
          _testPhase = TestPhase.distanceCalibration;
          break;
        case TestPhase.distanceCalibration:
          _startSnellenTest();
          break;
        default:
          break;
      }
    });
  }

  void _showOverallResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, Colors.teal.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility, color: Colors.white, size: 60),
                const SizedBox(height: 15),
                const Text(
                  "Your ClearView Summary",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                _buildResultRow("Name", _patientName),
                _buildResultRow("Age", _userAge.toString()),
                const SizedBox(height: 20),
                _buildResultRow("Left Eye Acuity", _leftEyeSnellenAcuity),
                _buildResultRow("Left Eye Power", "${_leftEyePower.toStringAsFixed(2)} D"),
                _buildResultRow("Left Eye Condition", _leftEyeCondition.toString().split('.').last.toUpperCase()),
                const SizedBox(height: 20),
                _buildResultRow("Right Eye Acuity", _rightEyeSnellenAcuity),
                _buildResultRow("Right Eye Power", "${_rightEyePower.toStringAsFixed(2)} D"),
                _buildResultRow("Right Eye Condition", _rightEyeCondition.toString().split('.').last.toUpperCase()),
                const SizedBox(height: 20),
                _buildResultRow("Depth Perception", _depthPerceptionPassed ? "Passed" : "Failed"),
                const SizedBox(height: 30),
                Text(
                  "Disclaimer: This is a simulated test and not a substitute for a professional eye examination.",
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.teal.shade100),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _animatedButton(
                  "Finish Test",
                  Colors.teal.shade300,
                  () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back from test screen
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 18, color: Colors.teal.shade100, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _animatedButton(String text, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        child: Text(text, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[50],
      appBar: AppBar(
        backgroundColor: Colors.teal[800],
        title: const Text("ClearView Eye Test", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: _buildCurrentPhaseUI(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPhaseUI() {
    switch (_testPhase) {
      case TestPhase.welcome:
        return Column(
          children: [
            Text("Welcome to ClearView Eye Test!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal[800]), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            _animatedButton("Start Test", Colors.teal, () => _moveToNextPhase()),
          ],
        );
      case TestPhase.nameInput:
        return Column(
          children: [
            Text("Let's start! What's your name?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal[800]), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: 250,
              child: TextField(
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, color: Colors.teal[800], fontWeight: FontWeight.bold),
                decoration: InputDecoration(hintText: "Your Name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onChanged: (value) => _patientName = value,
                onSubmitted: (value) {
                  setState(() {
                    _patientName = value;
                    _moveToNextPhase();
                  });
                },
              ),
            ),
            const SizedBox(height: 30),
            _animatedButton("Confirm Name & Continue", Colors.teal, () => setState(() => _moveToNextPhase())),
          ],
        );
      case TestPhase.ageInput:
        return Column(
          children: [
            Text("Hello ${_patientName.split(' ')[0]}! Please enter your age:", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal[800]), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: 100,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, color: Colors.teal[800], fontWeight: FontWeight.bold),
                decoration: InputDecoration(hintText: "Age", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onChanged: (value) => _userAge = int.tryParse(value) ?? 30,
                onSubmitted: (value) {
                  setState(() {
                    _userAge = int.tryParse(value) ?? 30;
                    _moveToNextPhase();
                  });
                },
              ),
            ),
            const SizedBox(height: 30),
            _animatedButton("Confirm Age & Continue", Colors.teal, () => setState(() => _moveToNextPhase())),
          ],
        );
      case TestPhase.distanceCalibration:
        return Column(
          children: [
            Text("Position yourself correctly. Your face should be within the green box.", style: TextStyle(fontSize: 20, color: Colors.teal[800]), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (_isCameraInitialized)
              SizedBox(
                height: 200,
                width: 300,
                child: Stack(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(15), child: CameraPreview(_cameraController!)),
                    Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(border: Border.all(color: _isAtCorrectDistance ? Colors.green : Colors.red, width: 4), borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
            else
              const CircularProgressIndicator(color: Colors.teal),
            const SizedBox(height: 20),
            _animatedButton(
              "Confirm Distance",
              _isAtCorrectDistance ? Colors.green : Colors.teal,
              () {
                setState(() {
                  _isAtCorrectDistance = true;
                  _moveToNextPhase();
                });
              },
            ),
          ],
        );
      case TestPhase.snellenChart:
        return _buildSnellenChartTestUI();
      case TestPhase.refractionTest:
        final options = _getOptions();
        return Column(
          children: [
            Text("Which text looks clearer?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[800]), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text("Option A", style: TextStyle(fontSize: 18, color: Colors.teal[700])),
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: _getBlurSigma(options[0]), sigmaY: _getBlurSigma(options[0])),
                        child: Text("ClearView", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal[800])),
                      ),
                      const SizedBox(height: 20),
                      _animatedButton("A is Clearer", Colors.teal.shade700, () => _processABRefractionChoice(1)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text("Option B", style: TextStyle(fontSize: 18, color: Colors.teal[700])),
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: _getBlurSigma(options[1]), sigmaY: _getBlurSigma(options[1])),
                        child: Text("ClearView", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal[800])),
                      ),
                      const SizedBox(height: 20),
                      _animatedButton("B is Clearer", Colors.teal.shade700, () => _processABRefractionChoice(2)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _animatedButton("Both Equal", Colors.teal.shade500, () => _processABRefractionChoice(0)),
          ],
        );
      case TestPhase.duochromeTest:
        return _buildDuochromeTestUI();
      case TestPhase.astigmatismTest:
        return _buildAstigmatismTestUI();
      case TestPhase.depthPerceptionTest:
        return Column(
          children: [
            Text("Which circle appears closer?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[800]), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => _processDepthPerceptionChoice(true),
                  child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.shade300, boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(2, 2))])),
                ),
                GestureDetector(
                  onTap: () => _processDepthPerceptionChoice(false),
                  child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.shade600)),
                ),
              ],
            ),
          ],
        );
      case TestPhase.finished:
        return Column(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            Text("All tests completed!", style: TextStyle(fontSize: 22, color: Colors.teal[800], fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            _animatedButton("Show Results", Colors.teal.shade700, () => _showOverallResult()),
          ],
        );
    }
  }

  Widget _buildSnellenChartTestUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Snellen Chart Test", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal[800]), textAlign: TextAlign.center),
        const SizedBox(height: 30),
        Text("Can you read the line?", style: TextStyle(fontSize: 20, color: Colors.teal[800])),
        const SizedBox(height: 20),
        Text(_snellenLines[_currentSnellenLine], style: TextStyle(fontSize: max(24.0, 60 - _currentSnellenLine * 4.0), fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.teal[800])),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _animatedButton("Yes", Colors.teal, () => _nextSnellenLine(true)),
            const SizedBox(width: 20),
            _animatedButton("No", Colors.teal, () => _nextSnellenLine(false)),
          ],
        ),
      ],
    );
  }

  Widget _buildDuochromeTestUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Duochrome Test", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal[800]), textAlign: TextAlign.center),
        const SizedBox(height: 30),
        Text("Which background makes the letters appear clearer?", style: TextStyle(fontSize: 18, color: Colors.teal[700]), textAlign: TextAlign.center),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: GestureDetector(onTap: () => _handleDuochromeResult('red'), child: Container(height: 150, color: Colors.red.shade700, alignment: Alignment.center, child: const Text("A B C", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white))))),
            Expanded(child: GestureDetector(onTap: () => _handleDuochromeResult('green'), child: Container(height: 150, color: Colors.green.shade700, alignment: Alignment.center, child: const Text("D E F", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white))))),
          ],
        ),
        const SizedBox(height: 30),
        _animatedButton("Both Equal", Colors.teal.shade500, () => _handleDuochromeResult('equal')),
      ],
    );
  }

  Widget _buildAstigmatismTestUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Astigmatism Test", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal[800]), textAlign: TextAlign.center),
        const SizedBox(height: 30),
        Text("Do any lines appear bolder than others?", style: TextStyle(fontSize: 18, color: Colors.teal[700]), textAlign: TextAlign.center),
        const SizedBox(height: 30),
        Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2), shape: BoxShape.circle), child: CustomPaint(painter: _ClockDialPainter())),
        const SizedBox(height: 30),
        _animatedButton("All lines are equal", Colors.green, () => _handleAstigmatismResult("No significant astigmatism detected.")),
        const SizedBox(height: 15),
        _animatedButton("Some lines are darker", Colors.red, () => _handleAstigmatismResult("Astigmatism may be present.")),
      ],
    );
  }
}

class _ClockDialPainter extends CustomPainter {
  final Paint _linePaint = Paint()
    ..color = Colors.black
    ..strokeWidth = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 12; i++) {
      final double angle = 2 * pi * (i / 12);
      final double startX = center.dx + radius * cos(angle);
      final double startY = center.dy + radius * sin(angle);
      final double endX = center.dx + (radius * 0.7) * cos(angle);
      final double endY = center.dy + (radius * 0.7) * sin(angle);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), _linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
