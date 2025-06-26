import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui'; // For ImageFilter

class EyeTestScreen extends StatefulWidget {
  const EyeTestScreen({super.key});

  @override
  _EyeTestScreenState createState() => _EyeTestScreenState();
}

class _EyeTestScreenState extends State<EyeTestScreen> {
  // --- Test State Variables ---
  // Represents the current estimated diopter power. Starts at a typical myopia value.
  double _currentDiopter = -1.0;
  // The step size for refining the diopter power. Decreases as the test progresses.
  double _stepSize = 0.5;
  // Controls the current phase of the test: baseline blur, A/B comparison, or result.
  TestPhase _testPhase = TestPhase.initialBlur;
  // Keeps track of which eye is currently being tested (true for left eye first, then right).
  bool _testingLeftEye = true;
  // Stores the final diopter power for the left eye.
  double? _leftEyePower;
  // Stores the final diopter power for the right eye.
  double? _rightEyePower;

  // --- Constants ---
  // The text displayed for the blur test. Could be a Snellen chart line or a simple paragraph.
  final String _testText = "E D F C Z P\nL E F O D P C T\nF D P L T E C O";
  // The threshold for stepSize at which the test is considered complete for one eye.
  static const double _minStepSize = 0.05;
  // The scaling factor to convert diopters to blur sigma for ImageFilter.
  // This value is empirical and might need fine-tuning for visual realism.
  static const double _diopterToSigmaFactor = 3.0; // Higher factor = more blur per diopter

  @override
  void initState() {
    super.initState();
    // Start with the initial blur state.
    _testPhase = TestPhase.initialBlur;
  }

  // --- Helper Functions ---

  /// Calculates the blur sigma for ImageFilter.blur based on diopter power.
  /// Negative diopters (myopia) should result in blur. Positive diopters (hyperopia)
  /// or zero diopters (emmetropia) would ideally mean no blur or different blur.
  /// For this simulation, we're focusing on myopia, so negative diopters cause blur.
  /// A higher absolute diopter value means more blur.
  double _getBlurSigma(double diopter) {
    // If diopter is positive or near zero, assume minimal blur for this myopia test.
    if (diopter >= 0) return 0.0;
    // For negative diopters, absolute value * factor determines blur strength.
    return diopter.abs() * _diopterToSigmaFactor;
  }

  /// Calculates the diopter values for Option A and Option B based on current state.
  List<double> _getOptions() {
    // Option A: slightly less negative (clearer for someone who needs less correction)
    double optionA = _currentDiopter + _stepSize / 2;
    // Option B: slightly more negative (clearer for someone who needs more correction)
    double optionB = _currentDiopter - _stepSize / 2;

    // Ensure options don't become positive or too small, keep them relevant for myopia range.
    optionA = min(0.0, optionA); // Don't go positive
    optionB = min(0.0, optionB); // Don't go positive

    // Ensure they are distinct enough if stepSize is still large.
    // If optionA and optionB are too close, make them more spread out for initial steps.
    if (_stepSize > 0.1 && (optionA - optionB).abs() < _stepSize / 2) {
      optionA = _currentDiopter + _stepSize;
      optionB = _currentDiopter - _stepSize;
    }

    return [optionA, optionB];
  }

  /// Processes the user's choice from the A/B comparison.
  void _processABChoice(int choice) {
    setState(() {
      final options = _getOptions();
      double optionA = options[0];
      double optionB = options[1];

      // Reduce step size for refinement
      _stepSize /= 2;

      if (_stepSize < _minStepSize) {
        // Test finished for this eye
        _finalizeABTest(_currentDiopter);
        return;
      }

      if (choice == 1) { // Option A is clearer
        _currentDiopter = optionA;
      } else if (choice == 2) { // Option B is clearer
        _currentDiopter = optionB;
      } else { // Both are equal
        _finalizeABTest(_currentDiopter);
        return;
      }
    });
  }

  /// Finalizes the A/B test for the current eye and presents the result.
  void _finalizeABTest(double finalPower) {
    setState(() {
      if (_testingLeftEye) {
        _leftEyePower = finalPower;
      } else {
        _rightEyePower = finalPower;
      }
      _testPhase = TestPhase.result;
    });

    // Show result dialog.
    showDialog(
      context: context,
      barrierDismissible: false, // User must interact with buttons
      builder: (_) => AlertDialog(
        title: Text(
          "${_testingLeftEye ? "Left" : "Right"} Eye Test Result",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.teal[800],
          ),
        ),
        content: Text(
          "Estimated lens power: ${finalPower.toStringAsFixed(2)} Diopters",
          style: TextStyle(
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close result dialog
              if (_testingLeftEye) {
                // Start right eye test
                setState(() {
                  _testingLeftEye = false;
                  _currentDiopter = -1.0; // Reset for next eye
                  _stepSize = 0.5; // Reset step size
                  _testPhase = TestPhase.initialBlur;
                });
              } else {
                // Both eyes tested, go to final overall result (or dismiss)
                setState(() {
                  _testPhase = TestPhase.finished;
                });
                _showOverallResult(); // Show combined result
              }
            },
            child: Text(
              _testingLeftEye ? "Start Right Eye Test" : "Show Overall Result",
              style: TextStyle(fontSize: 16, color: Colors.teal[600]),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a final dialog with results for both eyes.
  void _showOverallResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(
          "Overall Eye Test Results",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.teal[800],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Left Eye Power: ${_leftEyePower?.toStringAsFixed(2) ?? "N/A"} D",
              style: TextStyle(fontSize: 18, color: Colors.black87),
            ),
            SizedBox(height: 10),
            Text(
              "Right Eye Power: ${_rightEyePower?.toStringAsFixed(2) ?? "N/A"} D",
              style: TextStyle(fontSize: 18, color: Colors.black87),
            ),
            SizedBox(height: 20),
            Text(
              "Disclaimer: This is a simulated test and not a substitute for a professional eye examination.",
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss overall result
              // Reset the entire test for a new session
              setState(() {
                _currentDiopter = -1.0;
                _stepSize = 0.5;
                _testPhase = TestPhase.initialBlur;
                _testingLeftEye = true;
                _leftEyePower = null;
                _rightEyePower = null;
              });
            },
            child: Text(
              "Start New Test",
              style: TextStyle(fontSize: 16, color: Colors.teal[600]),
            ),
          ),
        ],
      ),
    );
  }


  // --- UI Building Blocks ---

  Widget _animatedButton(String text, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      splashColor: color.withOpacity(0.3),
      child: Ink(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        child: Text(
          text,
          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[50],
      appBar: AppBar(
        backgroundColor: Colors.teal[800],
        title: const Text(
          "ClearView Eye Test",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Instruction text
              Text(
                "Please cover your ${_testingLeftEye ? "right" : "left"} eye and stand 1 meter away.",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),

              // --- Content based on Test Phase ---
              if (_testPhase == TestPhase.initialBlur) ...[
                // Baseline Blurry Text
                Text(
                  "Is this text blurry?",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),
                SizedBox(height: 20),
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Initial fixed blur
                  child: Text(
                    _testText,
                    style: TextStyle(
                      fontSize: 32, // Large font for initial blur
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: Colors.teal[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 40),
                _animatedButton("Yes, it's blurry", Colors.teal, () {
                  setState(() {
                    _testPhase = TestPhase.abComparison;
                  });
                }),
              ] else if (_testPhase == TestPhase.abComparison) ...[
                // A/B Comparison Interface
                Text(
                  "Which text looks clearer?",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            "Option A (${_getOptions()[0].toStringAsFixed(2)} D)",
                            style: TextStyle(fontSize: 18, color: Colors.teal[700]),
                          ),
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: _getBlurSigma(_getOptions()[0]),
                              sigmaY: _getBlurSigma(_getOptions()[0]),
                            ),
                            child: Text(
                              _testText,
                              style: TextStyle(
                                fontSize: 32, // Consistent font size for comparison
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Colors.teal[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 20),
                          _animatedButton("Option A Clearer", Colors.teal.shade700, () => _processABChoice(1)),
                        ],
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            "Option B (${_getOptions()[1].toStringAsFixed(2)} D)",
                            style: TextStyle(fontSize: 18, color: Colors.teal[700]),
                          ),
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: _getBlurSigma(_getOptions()[1]),
                              sigmaY: _getBlurSigma(_getOptions()[1]),
                            ),
                            child: Text(
                              _testText,
                              style: TextStyle(
                                fontSize: 32, // Consistent font size for comparison
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Colors.teal[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 20),
                          _animatedButton("Option B Clearer", Colors.teal.shade700, () => _processABChoice(2)),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                _animatedButton("Both are Equal", Colors.teal.shade500, () => _processABChoice(0)),
              ] else if (_testPhase == TestPhase.finished) ...[
                // Test finished overall, waiting for overall result dialog
                Text(
                  "Test complete for both eyes.",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                _animatedButton("View Results", Colors.teal, _showOverallResult),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Enum to manage test phases
enum TestPhase {
  initialBlur,
  abComparison,
  result, // Individual eye result shown in dialog
  finished, // Both eyes tested, waiting for overall result
}
