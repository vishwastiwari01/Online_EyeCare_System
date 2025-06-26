import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'eye_test_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7F3F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF014D4E),
        elevation: 0,
        title: Text(
          'ClearView',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          _navButton(context, "Dashboard"),
          _navButton(context, "About"),
          _navButton(context, "Start Test"),
          IconButton(
            onPressed: _logout,
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            color: Colors.white, // Ensure icon color is visible
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _heroSection(context),
            _featuresSection(),
            _dashboardPreview(),
          ],
        ),
      ),
    );
  }

  Widget _navButton(BuildContext context, String title) {
    return TextButton(
      onPressed: () {
        if (title == "Start Test") {
          Navigator.pushNamed(context, '/eye_test');
        } else if (title == "Dashboard") {
          Navigator.pushNamed(context, '/dashboard');
        }
        // "About" doesn't navigate anywhere now
      },
      child: Text(
        title,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
      ),
    );
  }

  Widget _heroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      color: const Color(0xFF014D4E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF64FFDA).withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF64FFDA).withOpacity(0.6),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.remove_red_eye, size: 100, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "ClearView",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 56,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Your Virtual Eye Care Assistant",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 24, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/eye_test');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF014D4E),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            child: const Text("Start Your Test"),
          )
        ],
      ),
    );
  }

  Widget _featuresSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            "Why Choose ClearView?",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Text(
            "Our AI-powered virtual eye tests bring accuracy and convenience right to your screen.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _dashboardPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Dashboard Preview",
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF014D4E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _dashboardCard("Last Test", "Normal Vision"),
              _dashboardCard("Next Check", "May 25, 2025"),
              _dashboardCard("Tips", "Protect from UV"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dashboardCard(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF014D4E)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}