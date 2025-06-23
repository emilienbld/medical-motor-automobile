
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

  // VARIABLES CORRIGÉES pour gérer le joystick
  String? _lastSentCommand; // Dernière commande envoyée
  bool _isMoving = false; // État du mouvement
  
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

  // MÉTHODE CORRIGÉE - Envoi direct sans débouncing excessif
  Future<void> sendCommand(String direction) async {
    if (!isConnected) {
      print('❌ Pas de connexion pour envoyer: $direction');
      return;
    }

    try {
      // Envoyer commande immédiatement
      final response = await http
          .get(
            Uri.parse(
                "http://${_connectionManager.arduinoIP}/move?dir=$direction"),
          )
          .timeout(const Duration(seconds: 1));

      if (response.statusCode == 200) {
        print("✅ Commande envoyée: $direction");
        setState(() {
          currentCommand = direction;
        });
        
        // Effacer l'affichage après un court délai
        Timer(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              currentCommand = null;
            });
          }
        });
      } else {
        print("❌ Échec envoi commande: $direction");
      }
    } catch (e) {
      print("❌ Erreur lors de l'envoi de la commande: $e");
    }
  }

  // Déterminer la direction CORRIGÉE avec debug
  String _getDirection(double x, double y, double seuil) {
    // VÉRIFICATION : afficher les valeurs pour debug
    print('DEBUG: x=$x, y=$y, seuil=$seuil');
    
    // Zone morte d'abord
    double amplitude = sqrt(x * x + y * y);
    if (amplitude < seuil) {
      print('DEBUG: Zone morte - STOP');
      return "stop";
    }
    
    // CORRECTION MAJEURE : vérifier l'orientation du joystick
    // Certains joysticks ont des coordonnées inversées
    
    // Mouvements cardinaux PURS d'abord (pas de diagonales)
    // On utilise des seuils plus stricts pour éviter la confusion
    double absX = x.abs();
    double absY = y.abs();
    
    // Si mouvement principalement horizontal
    if (absX > absY && absX > seuil) {
      if (x > 0) {
        print('DEBUG: Mouvement pur DROITE');
        return "right";
      } else {
        print('DEBUG: Mouvement pur GAUCHE');  
        return "left";
      }
    }
    
    // Si mouvement principalement vertical
    if (absY > absX && absY > seuil) {
      if (y < 0) {
        print('DEBUG: Mouvement pur AVANT');
        return "forward";
      } else {
        print('DEBUG: Mouvement pur ARRIÈRE');
        return "backward";
      }
    }
    
    // Seulement APRÈS, les diagonales (avec seuil plus élevé)
    if (absX > seuil * 0.7 && absY > seuil * 0.7) {
      if (y < 0 && x > 0) {
        print('DEBUG: Diagonale AVANT-DROITE');
        return "forward_right";
      }
      if (y < 0 && x < 0) {
        print('DEBUG: Diagonale AVANT-GAUCHE');
        return "forward_left";
      }
      if (y > 0 && x > 0) {
        print('DEBUG: Diagonale ARRIÈRE-DROITE');
        return "backward_right";
      }
      if (y > 0 && x < 0) {
        print('DEBUG: Diagonale ARRIÈRE-GAUCHE');
        return "backward_left";
      }
    }
    
    print('DEBUG: Aucune direction détectée - STOP');
    return "stop";
  }

  // MÉTHODE ENTIÈREMENT REÉCRITE du joystick avec protection
  void _onJoystickMove(double x, double y) {
    print('Joystick RAW: x=${x.toStringAsFixed(2)}, y=${y.toStringAsFixed(2)}');

    // Seuil pour éviter la sensibilité excessive
    const seuil = 0.4;
    
    // Déterminer la direction actuelle avec la nouvelle logique
    String currentDirection = _getDirection(x, y, seuil);
    
    // PROTECTION ANTI-BOUCLE : si c'est la même direction, ne rien faire
    if (currentDirection == _lastSentCommand) {
      // Ne pas renvoyer la même commande
      return;
    }
    
    print("🎮 Changement: $_lastSentCommand -> $currentDirection");
    
    // Mettre à jour AVANT d'envoyer pour éviter les boucles
    _lastSentCommand = currentDirection;
    _isMoving = (currentDirection != "stop");
    
    // Envoyer la commande
    sendCommand(currentDirection);
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
                'Utilisez le joystick pour déplacer le robot (mode réactif)',
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

              const SizedBox(height: 20),

              // Debug info AMÉLIORÉ pour diagnostic
              if (isConnected)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey, width: 1),
                  ),
                  child: Column(
                    children: [
                      if (_lastSentCommand != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gamepad, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              'Direction: $_lastSentCommand',
                              style: const TextStyle(fontSize: 10, color: Colors.green),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      const Text(
                        'TEST: Bougez le joystick à fond à droite puis à gauche',
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

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
                        'Envoyé: $currentCommand',
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