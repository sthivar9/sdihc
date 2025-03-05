import 'package:flutter/material.dart';
import 'package:sdihc/pages/Tabs/home_tab.dart';
import 'package:sdihc/pages/Tabs/newProfilePage.dart';
import 'package:sdihc/pages/functionPages/options.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // List of tabs
  final List<Widget> _tabs = [
    const SalesChartPage(), // Line chart of daily sales
    const newAddPage(), // Form to add sales
    const NewProfilePage(), // User profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex], // Switch between tabs
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_chart),
            label: 'Add Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
