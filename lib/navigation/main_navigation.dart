import 'package:flutter/material.dart';
import '../screens/connexion_page.dart';
import '../screens/wifi_page.dart';
import '../screens/automatique_page.dart';
import '../screens/manuel_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({Key? key}) : super(key: key);

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 1; // Démarre sur WiFi
  
  final List<Widget> _pages = [
    const ConnexionPage(),      // Index 0
    const WifiPage(),           // Index 1
    const AutomatiquePage(),    // Index 2
    const ManuelPage(),         // Index 3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Navigation tabs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildTab('Connexion', 0),
                  _buildTab('WiFi', 1),           // ← Corrigé : index 1
                  _buildTab('Automatique', 2),    // ← Corrigé : index 2
                  _buildTab('Manuel', 3),         // ← Corrigé : index 3
                ],
              ),
            ),
            // Content
            Expanded(
              child: _pages[_currentIndex],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.blue : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}