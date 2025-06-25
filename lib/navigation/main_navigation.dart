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
  int _currentIndex = 0; // Démarre sur Accueil
  
  final List<Widget> _pages = [
    const ConnexionPage(),      // Index 0 - Accueil
    const WifiPage(),           // Index 1 - Connexion
    const AutomatiquePage(),    // Index 2 - Automatique
    const ManuelPage(),         // Index 3 - Manuel
  ];

  final List<String> _titles = [
    'Accueil',
    'Connexion',
    'Automatique',
    'Manuel',
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
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildTab(_titles[0], 0),
                    _buildTab(_titles[1], 1),
                    _buildTab(_titles[2], 2),
                    _buildTab(_titles[3], 3),
                  ],
                ),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.green : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? Colors.green : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}