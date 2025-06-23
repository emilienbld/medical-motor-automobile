// services/robot_control_service.dart
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'wifi_connection_manager.dart';

class RobotControlService {
  final WiFiConnectionManager _connectionManager;
  
  // État du contrôle
  String? _lastSentCommand;
  bool _isMoving = false;
  String? _currentCommand;
  Timer? _commandTimer;
  
  // Streams pour notifier l'UI
  final StreamController<String?> _commandController = StreamController<String?>.broadcast();
  final StreamController<String?> _lastCommandController = StreamController<String?>.broadcast();
  
  RobotControlService(this._connectionManager);
  
  // Getters pour l'état
  String? get lastSentCommand => _lastSentCommand;
  bool get isMoving => _isMoving;
  String? get currentCommand => _currentCommand;
  
  // Streams pour l'UI
  Stream<String?> get commandStream => _commandController.stream;
  Stream<String?> get lastCommandStream => _lastCommandController.stream;
  
  // Vérifier si connecté
  bool get isConnected => _connectionManager.isConnected;
  
  // Envoyer une commande au robot
  Future<void> sendCommand(String direction) async {
    if (!isConnected) {
      print('❌ Pas de connexion pour envoyer: $direction');
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
                "http://${_connectionManager.arduinoIP}/move?dir=$direction"),
          )
          .timeout(const Duration(seconds: 1));

      if (response.statusCode == 200) {
        print("✅ Commande envoyée: $direction");
        _currentCommand = direction;
        _commandController.add(direction);
        
        // Effacer l'affichage après un court délai
        Timer(const Duration(milliseconds: 200), () {
          _currentCommand = null;
          _commandController.add(null);
        });
      } else {
        print("❌ Échec envoi commande: $direction");
      }
    } catch (e) {
      print("❌ Erreur lors de l'envoi de la commande: $e");
    }
  }
  
  // Logique de détermination de direction
  String _getDirection(double x, double y, double seuil) {
    print('DEBUG: x=$x, y=$y, seuil=$seuil');
    
    // Zone morte d'abord
    double amplitude = sqrt(x * x + y * y);
    if (amplitude < seuil) {
      print('DEBUG: Zone morte - STOP');
      return "stop";
    }
    
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
    
    // Diagonales
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
  
  // Traiter le mouvement du joystick
  void handleJoystickMove(double x, double y) {
    print('Joystick RAW: x=${x.toStringAsFixed(2)}, y=${y.toStringAsFixed(2)}');

    const seuil = 0.4;
    String currentDirection = _getDirection(x, y, seuil);
    
    // Protection anti-boucle
    if (currentDirection == _lastSentCommand) {
      return;
    }
    
    print("🎮 Changement: $_lastSentCommand -> $currentDirection");
    
    _lastSentCommand = currentDirection;
    _isMoving = (currentDirection != "stop");
    _lastCommandController.add(currentDirection);
    
    sendCommand(currentDirection);
  }
  
  // Nettoyer les ressources
  void dispose() {
    _commandTimer?.cancel();
    _commandController.close();
    _lastCommandController.close();
  }
}