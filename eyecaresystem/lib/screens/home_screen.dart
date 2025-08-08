import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      duration: const Duration(seconds: 2, milliseconds: 500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
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
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          _navButton(context, "Dashboard", () => Navigator.pushNamed(context, '/dashboard')),
          _navButton(context, "Logout", () => _logout(context)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _heroSection(context),
            _featuresSection(context),
          ],
        ),
      ),
    );
  }

  Widget _navButton(BuildContext context, String title, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        title,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
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
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF64FFDA).withOpacity(0.1),
              ),
              child: const Icon(Icons.remove_red_eye, size: 96, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "ClearView",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 56,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your Virtual Eye Care Assistant",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 22, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/eye_test');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF014D4E),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            child: const Text("Start Your Test"),
          )
        ],
      ),
    );
  }

  Widget _featuresSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            "Our Features",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 24),
          _featureCard(
            context,
            icon: Icons.checklist_rtl,
            title: "Comprehensive Screening",
            subtitle: "Your original, detailed multi-step eye exam.",
            iconColor: Colors.teal,
            onTap: () => Navigator.pushNamed(context, '/eye_test'),
          ),
          const SizedBox(height: 16),
          _featureCard(
            context,
            icon: Icons.history,
            title: "Track Your History",
            subtitle: "View and monitor your results over time.",
            iconColor: Colors.blue,
            onTap: () => Navigator.pushNamed(context, '/dashboard'),
          ),
          const SizedBox(height: 16),
          // --- NEW FEATURE CARD ADDED HERE ---
          _featureCard(
            context,
            icon: Icons.camera,
            title: "Keratometry Simulation",
            subtitle: "Estimate corneal curvature with your camera.",
            iconColor: Colors.purple,
            onTap: () => Navigator.pushNamed(context, '/keratometry'),
          ),
        ],
      ),
    );
  }

  Widget _featureCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
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
