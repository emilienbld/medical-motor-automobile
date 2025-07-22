// main.dart - AVEC AUTHENTIFICATION
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ AJOUTÉ
import 'firebase_options.dart';
import 'navigation/main_navigation.dart';
import 'screens/login_page.dart'; // ✅ AJOUTÉ
import 'services/wifi_connection_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      
      // ✅ GESTION DE L'AUTHENTIFICATION
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Attendre la vérification de l'état d'authentification
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingPage();
          }
          
          // Si utilisateur connecté → Application principale
          if (snapshot.hasData) {
            return const MainNavigationPage();
          }
          
          // Si pas connecté → Page de connexion
          return const LoginPage();
        },
      ),
      
      debugShowCheckedModeBanner: false,
    );
  }
}

// ✅ Page de chargement pendant vérification auth
class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.medical_services,
                size: 60,
                color: Colors.green[600],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'ZIGGY CAR',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green[600],
              ),
            ),
            
            const SizedBox(height: 32),
            
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Chargement...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}