// import 'package:flutter/material.dart';
// import '../widgets/joystick_widget.dart';
// import 'package:http/http.dart' as http;
// import '../services/wifi_connection_manager.dart'; // AJOUTÉ
// import 'dart:async'; // AJOUTÉ
// class ManuelPage extends StatefulWidget {
//   const ManuelPage({Key? key}) : super(key: key);

//   @override
//   State<ManuelPage> createState() => _ManuelPageState();
// }

// class _ManuelPageState extends State<ManuelPage> {
//   bool modeAutonome = false;
//   double statistiqueTrajet = 100;
//   String etatConnexion = 'CONNECTÉ';
//   String signalForce = 'Fort';

//   Future<void> sendCommand(String direction) async {
//     try {
//       final response = await http.get(
//         Uri.parse("http://192.168.4.1/move?dir=$direction"),
//       );
//       print("Commande envoyée: $direction | Réponse: ${response.statusCode}");
//     } catch (e) {
//       print("Erreur lors de l'envoi de la commande: $e");
//     }
//   }

//   void _onJoystickMove(double x, double y) {
//     print('Joystick position: x=$x, y=$y');

//     const seuil = 0.5;

//     if (y < -seuil) {
//       sendCommand("forward");
//     } else if (y > seuil) {
//       sendCommand("backward");
//     } else if (x > seuil) {
//       sendCommand("right");
//     } else if (x < -seuil) {
//       sendCommand("left");
//     } else {
//       sendCommand("stop");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: SingleChildScrollView(
//           child: Column(
//             children: [
//               // Header
//               const Text(
//                 'Navigation autonome',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               const Text(
//                 'Contrôle manuel',
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Colors.grey,
//                 ),
//               ),
//               const Text(
//                 'Utilisez le joystick pour déplacer le robot',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.grey,
//                 ),
//               ),
//               const Text(
//                 '• Robot disponible',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.green,
//                 ),
//               ),

//               const SizedBox(height: 40),

//               // Joystick
//               JoystickWidget(
//                 onJoystickMove: _onJoystickMove,
//               ),

//               const SizedBox(height: 40),

//               // Mode autonomous toggle
//               Row(
//                 children: [
//                   Container(
//                     width: 8,
//                     height: 8,
//                     decoration: BoxDecoration(
//                       color: modeAutonome ? Colors.green : Colors.grey,
//                       shape: BoxShape.circle,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   const Expanded(
//                     child: Text(
//                       'Mode autonome',
//                       style: TextStyle(fontSize: 14),
//                     ),
//                   ),
//                   Switch(
//                     value: modeAutonome,
//                     onChanged: (value) {
//                       setState(() => modeAutonome = value);
//                       if (value) {
//                         print('Mode autonome activé');
//                       } else {
//                         print('Mode manuel activé');
//                       }
//                     },
//                     activeColor: Colors.green,
//                   ),
//                 ],
//               ),

//               const SizedBox(height: 20),

//               // Statistics
//               const Text(
//                 'Statistique de trajet',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const SizedBox(height: 12),

//               Row(
//                 children: [
//                   const Text('100m',
//                       style: TextStyle(fontSize: 12, color: Colors.grey)),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Slider(
//                       value: statistiqueTrajet,
//                       min: 0,
//                       max: 200,
//                       activeColor: Colors.green,
//                       onChanged: (value) {
//                         setState(() => statistiqueTrajet = value);
//                       },
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   const Text('Suivi des mouvements',
//                       style: TextStyle(fontSize: 12, color: Colors.grey)),
//                 ],
//               ),

//               const SizedBox(height: 20),

//               // Connection Status
//               const Text(
//                 'État de la connexion',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const SizedBox(height: 12),

//               Row(
//                 children: [
//                   Container(
//                     width: 8,
//                     height: 8,
//                     decoration: const BoxDecoration(
//                       color: Colors.green,
//                       shape: BoxShape.circle,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Text(
//                     etatConnexion,
//                     style: const TextStyle(
//                       fontSize: 12,
//                       color: Colors.green,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const Spacer(),
//                   Text(
//                     signalForce,
//                     style: const TextStyle(
//                       fontSize: 12,
//                       color: Colors.grey,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import '../widgets/joystick_widget.dart';
import 'package:http/http.dart' as http;
import '../services/wifi_connection_manager.dart'; // AJOUTÉ
import 'dart:async'; // AJOUTÉ

class ManuelPage extends StatefulWidget {
  const ManuelPage({Key? key}) : super(key: key);

  @override
  State<ManuelPage> createState() => _ManuelPageState();
}

class _ManuelPageState extends State<ManuelPage> {
  bool modeAutonome = false;
  double statistiqueTrajet = 100;
  String etatConnexion = 'DÉCONNECTÉ'; // MODIFIÉ : valeur par défaut
  String signalForce = 'N/A'; // MODIFIÉ : valeur par défaut
  
  // AJOUTÉ : Variables pour le WiFiConnectionManager
  final WiFiConnectionManager _connectionManager = WiFiConnectionManager();
  StreamSubscription<bool>? _connectionSubscription;
  bool isConnected = false;
  String? currentCommand;
  Timer? _commandTimer;

  @override
  void initState() { // NOUVELLE MÉTHODE
    super.initState();
    
    // Récupérer l'état actuel de la connexion
    isConnected = _connectionManager.isConnected;
    _updateConnectionStatus();
    
    // Écouter les changements de connexion
    _connectionSubscription = _connectionManager.connectionStream.listen((connected) {
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
  void dispose() { // NOUVELLE MÉTHODE
    _connectionSubscription?.cancel();
    _commandTimer?.cancel();
    super.dispose();
  }

  // NOUVELLE MÉTHODE : Mettre à jour l'affichage de l'état de connexion
  void _updateConnectionStatus() {
    setState(() {
      if (isConnected) {
        etatConnexion = 'CONNECTÉ';
        signalForce = 'Fort';
      } else {
        etatConnexion = 'DÉCONNECTÉ';
        signalForce = 'N/A';
      }
    });
  }

  // MODIFIÉE : Utiliser le WiFiConnectionManager au lieu de l'IP hardcodée
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

  // NOUVELLE MÉTHODE : Envoyer commande avec l'ancien format
  Future<bool> _sendOldFormatCommand(String direction) async {
    try {
      final response = await http.get(
        Uri.parse("http://${_connectionManager.arduinoIP}/move?dir=$direction"),
      ).timeout(const Duration(seconds: 3));
      
      print("Commande envoyée: $direction | Réponse: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print("Erreur format ancien: $e");
      return false;
    }
  }

  void _onJoystickMove(double x, double y) {
    print('Joystick position: x=$x, y=$y');

    const seuil = 0.5;

    if (y < -seuil) {
      sendCommand("forward");
    } else if (y > seuil) {
      sendCommand("backward");
    } else if (x > seuil) {
      sendCommand("right");
    } else if (x < -seuil) {
      sendCommand("left");
    } else {
      sendCommand("stop");
    }
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
              // Header
              const Text(
                'Navigation autonome',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Contrôle manuel',
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
              
              // MODIFIÉ : Affichage dynamique de l'état du robot
              Text(
                isConnected ? '• Robot disponible' : '• Robot non connecté',
                style: TextStyle(
                  fontSize: 12,
                  color: isConnected ? Colors.green : Colors.red,
                ),
              ),

              const SizedBox(height: 40),

              // AJOUTÉ : Indicateur de connexion plus visible
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
              Opacity( // AJOUTÉ : Rendre le joystick transparent si pas connecté
                opacity: isConnected ? 1.0 : 0.5,
                child: JoystickWidget(
                  onJoystickMove: _onJoystickMove,
                ),
              ),

              const SizedBox(height: 40),

              // Mode autonomous toggle
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: modeAutonome ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Mode autonome',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Switch(
                    value: modeAutonome,
                    onChanged: isConnected ? (value) { // MODIFIÉ : Désactiver si pas connecté
                      setState(() => modeAutonome = value);
                      if (value) {
                        print('Mode autonome activé');
                        sendCommand('autonomous_on'); // AJOUTÉ : Envoyer commande
                      } else {
                        print('Mode manuel activé');
                        sendCommand('autonomous_off'); // AJOUTÉ : Envoyer commande
                      }
                    } : null, // Désactivé si pas connecté
                    activeColor: Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Statistics
              const Text(
                'Statistique de trajet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Text('100m',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: statistiqueTrajet,
                      min: 0,
                      max: 200,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() => statistiqueTrajet = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Suivi des mouvements',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),

              const SizedBox(height: 20),

              // Connection Status - MODIFIÉ pour être dynamique
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
                      color: isConnected ? Colors.green : Colors.red, // MODIFIÉ : couleur dynamique
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    etatConnexion,
                    style: TextStyle(
                      fontSize: 12,
                      color: isConnected ? Colors.green : Colors.red, // MODIFIÉ : couleur dynamique
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  
                  // AJOUTÉ : Afficher l'IP si connecté
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

              // AJOUTÉ : Affichage de la commande actuelle
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
                        style: const TextStyle(fontSize: 10, color: Colors.blue),
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