import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Sera généré par flutterfire configure
import 'navigation/main_navigation.dart';
import 'services/wifi_connection_manager.dart';

void main() async {
  // ✅ Ajout obligatoire
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Initialiser Firebase AVANT de lancer l'app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const ZiggyCarApp());
}

class ZiggyCarApp extends StatefulWidget {
  const ZiggyCarApp({Key? key}) : super(key: key);

  @override
  State<ZiggyCarApp> createState() => _ZiggyCarAppState();
}

class _ZiggyCarAppState extends State<ZiggyCarApp> with WidgetsBindingObserver {
  final WiFiConnectionManager _connectionManager = WiFiConnectionManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _connectionManager.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Gérer la pause/reprise de l'app pour optimiser la batterie
    if (state == AppLifecycleState.paused) {
      _connectionManager.stopHeartbeat();
    } else if (state == AppLifecycleState.resumed) {
      if (_connectionManager.isConnected) {
        _connectionManager.startHeartbeat();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZIGGY CAR',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro',
      ),
      home: const MainNavigationPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}