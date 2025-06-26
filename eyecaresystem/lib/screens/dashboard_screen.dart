
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  final List<Widget> _pages = [
    Center(child: Text("Welcome to ClearView!", style: TextStyle(fontSize: 24))),
    Center(child: Text("Your Eye Test Results", style: TextStyle(fontSize: 24))),
    Center(child: Text("Connect with a Doctor", style: TextStyle(fontSize: 24))),
  ];

  void onTabTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ClearView Dashboard"),
        backgroundColor: Colors.teal,
      ),
      body: _pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Results'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: 'Doctor'),
        ],
      ),
    );
  }
}
