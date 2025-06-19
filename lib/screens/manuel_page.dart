import 'package:flutter/material.dart';
import '../widgets/joystick_widget.dart';
import 'package:http/http.dart' as http;
import '../services/wifi_connection_manager.dart';
import 'dart:async';
import 'dart:math';
import 'package:webview_flutter/webview_flutter.dart';

class ManuelPage extends StatefulWidget {
  const ManuelPage({Key? key}) : super(key: key);

  @override
  State<ManuelPage> createState() => _ManuelPageState();
}

class _ManuelPageState extends State<ManuelPage> {
  bool modeAutonome = false;
  double statistiqueTrajet = 100;
  String etatConnexion = 'DÉCONNECTÉ';
  String signalForce = 'N/A';

  // Variables pour le WiFiConnectionManager
  final WiFiConnectionManager _connectionManager = WiFiConnectionManager();
  StreamSubscription<bool>? _connectionSubscription;
  bool isConnected = false;
  String? currentCommand;
  Timer? _commandTimer;

  // NOUVELLES VARIABLES pour gérer le joystick
  Timer? _stopTimer; // Timer pour forcer l'arrêt
  String? _lastSentCommand; // Dernière commande envoyée
  int _commandCount = 0; // Compteur pour éviter les spam
  bool _isMoving = false; // État du mouvement

  // Variables pour le démarrage progressif
  double _currentSpeed = 0.0; // Vitesse actuelle (0-100)
  Timer? _speedTimer; // Timer pour la progression de vitesse

  // Variables pour la caméra
  late final WebViewController _cameraController;
  bool _cameraLoaded = false;
  bool _showCamera = true;

  @override
  void initState() {
    super.initState();

    // Récupérer l'état actuel de la connexion
    isConnected = _connectionManager.isConnected;

    // Initialiser la caméra AVANT de mettre à jour le statut
    _initializeCameraController();
    _updateConnectionStatus();

    // Écouter les changements de connexion
    _connectionSubscription =
        _connectionManager.connectionStream.listen((connected) {
      setState(() {
        isConnected = connected;
        _updateConnectionStatus();
      });

      if (!connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Connexion Arduino perdue'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });

    // S'assurer que le heartbeat est actif si connecté
    if (isConnected) {
      _connectionManager.startHeartbeat();
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _commandTimer?.cancel();
    _stopTimer?.cancel(); 
    _speedTimer?.cancel(); 
    super.dispose();
  }

  // Mettre à jour l'affichage de l'état de connexion
  void _updateConnectionStatus() {
    setState(() {
      if (isConnected) {
        etatConnexion = 'CONNECTÉ';
        signalForce = 'Fort';
        _loadCameraStream();
      } else {
        etatConnexion = 'DÉCONNECTÉ';
        signalForce = 'N/A';
      }
    });
  }

  // Initialiser le contrôleur de caméra
  void _initializeCameraController() {
    _cameraController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('Caméra en cours de chargement: $progress%');
          },
          onPageStarted: (String url) {
            debugPrint('Caméra: chargement démarré');
            setState(() {
              _cameraLoaded = false;
            });
          },
          onPageFinished: (String url) {
            debugPrint('Caméra: chargement terminé');
            setState(() {
              _cameraLoaded = true;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Erreur caméra: ${error.description}');
            setState(() {
              _cameraLoaded = false;
            });
          },
        ),
      );

    // Charger le stream de la caméra
    if (isConnected) {
      _loadCameraStream();
    }
  }

  // Charger le stream de la caméra
  void _loadCameraStream() {
    String cameraUrl = "http://192.168.4.4";
    _cameraController.loadRequest(Uri.parse(cameraUrl));
  }

  // Utiliser le WiFiConnectionManager au lieu de l'IP hardcodée
  Future<void> sendCommand(String direction) async {
    if (!isConnected) {
      print('❌ Pas de connexion pour envoyer: $direction');
      return;
    }

    // Éviter d'envoyer la même commande en boucle
    if (currentCommand == direction) return;

    currentCommand = direction;

    // Limiter la fréquence des commandes
    _commandTimer?.cancel();
    _commandTimer = Timer(const Duration(milliseconds: 100), () {
      currentCommand = null;
    });

    try {
      // Option 1: Utiliser l'ancien format /move?dir= si votre Arduino l'attend
      bool success = await _sendOldFormatCommand(direction);

      // Option 2: Si ça ne marche pas, essayer le nouveau format /command
      if (!success) {
        success = await _connectionManager.sendCommand(direction.toUpperCase());
      }

      if (success) {
        print("✅ Commande envoyée: $direction");
      } else {
        print("❌ Échec envoi commande: $direction");
      }
    } catch (e) {
      print("❌ Erreur lors de l'envoi de la commande: $e");
    }
  }

  // Envoyer commande avec l'ancien format
  Future<bool> _sendOldFormatCommand(String direction) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                "http://${_connectionManager.arduinoIP}/move?dir=$direction"),
          )
          .timeout(const Duration(seconds: 3));

      print("Commande envoyée: $direction | Réponse: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print("Erreur format ancien: $e");
      return false;
    }
  }
  // NOUVELLE MÉTHODE : Démarrage progressif de la vitesse
  void _startProgressiveSpeed(String direction) {
    _speedTimer?.cancel();
    _currentSpeed = 30.0; // Vitesse de démarrage douce (30%)
    _isMoving = true;
    
    // Envoyer la première commande avec vitesse réduite
    _sendCommandWithSpeed(direction, _currentSpeed.round());
    
    // Augmenter progressivement la vitesse
    _speedTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentSpeed < 85.0) { // Vitesse max à 85% pour éviter les à-coups
        _currentSpeed += 15.0; // Augmentation progressive
        _sendCommandWithSpeed(direction, _currentSpeed.round());
      } else {
        timer.cancel(); // Arrêter l'augmentation
      }
    });
  }

   // NOUVELLE MÉTHODE : Arrêt forcé avec sécurité
  void _forceStop() {
    _speedTimer?.cancel();
    _currentSpeed = 0.0;
    _isMoving = false;
    _lastSentCommand = null;
    
    // Envoyer plusieurs commandes STOP pour être sûr
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        _sendDirectCommand("stop");
      });
    }
    
    print("🛑 ARRÊT FORCÉ du robot");
  }

  // NOUVELLE MÉTHODE : Gérer l'arrêt proprement
  void _handleStop() {
    if (_isMoving) {
      print("🛑 Joystick au centre - Arrêt");
      _forceStop();
      _resetStopTimer();
    }
  }

   // NOUVELLE MÉTHODE : Timer d'arrêt automatique (sécurité)
  void _resetStopTimer() {
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(milliseconds: 500), () {
      print("⏰ Timeout - Arrêt automatique");
      _forceStop();
    });
  }

  // NOUVELLE MÉTHODE : Envoyer commande avec vitesse
  Future<void> _sendCommandWithSpeed(String direction, int speed) async {
    if (!isConnected) return;

    try {
      // Format: /move?dir=forward&speed=50
      final response = await http.get(
        Uri.parse("http://${_connectionManager.arduinoIP}/move?dir=$direction&speed=$speed"),
      ).timeout(const Duration(seconds: 1));

      if (response.statusCode == 200) {
        print("✅ $direction (${speed}%)");
      }
    } catch (e) {
      print("❌ Erreur vitesse: $e");
      // Si ça ne marche pas avec speed, essayer sans
      _sendDirectCommand(direction);
    }
  }

  // NOUVELLE MÉTHODE : Commande directe (fallback)
  Future<void> _sendDirectCommand(String direction) async {
    if (!isConnected) return;

    try {
      final response = await http.get(
        Uri.parse("http://${_connectionManager.arduinoIP}/move?dir=$direction"),
      ).timeout(const Duration(seconds: 1));
      
      if (response.statusCode == 200) {
        print("✅ Commande directe: $direction");
      }
    } catch (e) {
      print("❌ Erreur commande directe: $e");
    }
  }

  // NOUVELLE MÉTHODE : Déterminer la direction
  String _getDirection(double x, double y, double seuil) {
    // Mouvements diagonaux (priorité)
    if (y < -seuil && x > seuil) return "forward_right";
    if (y < -seuil && x < -seuil) return "forward_left";
    if (y > seuil && x > seuil) return "backward_right";
    if (y > seuil && x < -seuil) return "backward_left";
    
    // Mouvements cardinaux
    if (y < -seuil) return "forward";
    if (y > seuil) return "backward";
    if (x > seuil) return "right";
    if (x < -seuil) return "left";
    
    return "stop";
  }

  void _onJoystickMove(double x, double y) {
    print('Joystick: x=$x, y=$y');

    // Augmenter le seuil pour réduire la sensibilité
    const seuil = 0.45; // Augmenté de 0.3 à 0.45
    double amplitude = sqrt(x * x + y * y);

    // Zone morte plus large pour éviter les démarrages accidentels
    if (amplitude < seuil) {
      _handleStop();
      return;
    }

    // Déterminer la direction
    String direction = _getDirection(x, y, seuil);
    
    // Si c'est une nouvelle direction ou le premier mouvement
    if (direction != _lastSentCommand || !_isMoving) {
      print("🎮 Nouvelle direction: $direction");
      _lastSentCommand = direction;
      _startProgressiveSpeed(direction);
    }

    // Réinitialiser le timer d'arrêt automatique
    _resetStopTimer();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text(
                'Contrôle manuel avec vision',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const Text(
                'Utilisez le joystick pour déplacer le robot',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 20),

              // Section Caméra
              Card(
                elevation: 4,
                child: Column(
                  children: [
                    // En-tête de la caméra
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.videocam,
                            size: 18,
                            color: _cameraLoaded ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Vision Robot',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _cameraLoaded ? Colors.black : Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _cameraLoaded ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _showCamera
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _showCamera = !_showCamera;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // Vue de la caméra
                    if (_showCamera) ...[
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: isConnected
                            ? Stack(
                                children: [
                                  WebViewWidget(controller: _cameraController),
                                  if (!_cameraLoaded)
                                    Container(
                                      color: Colors.black54,
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                                color: Colors.white),
                                            SizedBox(height: 8),
                                            Text(
                                              'Connexion caméra...',
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.videocam_off,
                                        color: Colors.grey, size: 40),
                                    SizedBox(height: 8),
                                    Text('Caméra non disponible',
                                        style: TextStyle(color: Colors.grey)),
                                    Text('Connectez-vous au robot',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Indicateur de connexion si pas connecté
              if (!isConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Robot non connecté. Allez dans l\'onglet WiFi pour vous connecter.',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),

              // Joystick
              Opacity(
                opacity: isConnected ? 1.0 : 0.5,
                child: JoystickWidget(
                  onJoystickMove: _onJoystickMove,
                ),
              ),

              const SizedBox(height: 40),

              // Connection Status
              const Text(
                'État de la connexion',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    etatConnexion,
                    style: TextStyle(
                      fontSize: 12,
                      color: isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),

                  // Afficher l'IP si connecté
                  if (isConnected) ...[
                    Text(
                      'IP: ${_connectionManager.arduinoIP}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  Text(
                    signalForce,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              // Affichage de la commande actuelle
              if (isConnected && currentCommand != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.send, size: 12, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'Commande: $currentCommand',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
