// services/robot_control_service.dart - VERSION CORRIGÉE
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
  
  // NOUVELLES VARIABLES pour corriger les problèmes
  Timer? _forceStopTimer;
  DateTime? _lastCommandTime;
  bool _isCommandInProgress = false;
  static const Duration _forceStopDelay = Duration(milliseconds: 500);
  
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
  
  // MÉTHODE CORRIGÉE - Envoyer une commande au robot avec protection
  Future<void> sendCommand(String direction) async {
    if (!isConnected) {
      print('❌ Pas de connexion pour envoyer: $direction');
      return;
    }

    // PROTECTION 1: Éviter les commandes en boucle
    if (_isCommandInProgress) {
      print('⚠️ Commande déjà en cours, ignorée: $direction');
      return;
    }

    _isCommandInProgress = true;
    _lastCommandTime = DateTime.now();
    
    try {
      print('📡 Envoi commande: $direction');
      
      final response = await http
          .get(
            Uri.parse("http://${_connectionManager.arduinoIP}/move?dir=$direction"),
          )
          .timeout(const Duration(milliseconds: 800)); // Timeout plus court

      if (response.statusCode == 200) {
        print("✅ Commande envoyée: $direction");
        _currentCommand = direction;
        _commandController.add(direction);
        
        // CORRECTION: Timer de nettoyage plus rapide
        _commandTimer?.cancel();
        _commandTimer = Timer(const Duration(milliseconds: 150), () {
          _currentCommand = null;
          _commandController.add(null);
        });
        
        // NOUVEAU: Démarrer le timer de force stop si ce n'est pas déjà un stop
        if (direction != "stop") {
          _resetForceStopTimer();
        }
        
      } else {
        print("❌ Échec envoi commande: $direction (${response.statusCode})");
        _sendEmergencyStop(); // Envoyer stop en cas d'erreur
      }
    } catch (e) {
      print("❌ Erreur lors de l'envoi de la commande: $e");
      _sendEmergencyStop(); // Envoyer stop en cas d'erreur
    } finally {
      _isCommandInProgress = false;
    }
  }
  
  // NOUVELLE MÉTHODE: Timer de sécurité pour forcer l'arrêt
  void _resetForceStopTimer() {
    _forceStopTimer?.cancel();
    _forceStopTimer = Timer(_forceStopDelay, () {
      print('🛑 TIMEOUT - Arrêt automatique de sécurité');
      _sendEmergencyStop();
    });
  }
  
  // NOUVELLE MÉTHODE: Arrêt d'urgence sans protection
  void _sendEmergencyStop() async {
    if (!isConnected) return;
    
    try {
      await http
          .get(Uri.parse("http://${_connectionManager.arduinoIP}/move?dir=stop"))
          .timeout(const Duration(milliseconds: 500));
      print('🛑 STOP d\'urgence envoyé');
    } catch (e) {
      print('❌ Erreur stop d\'urgence: $e');
    }
  }
  
  // MÉTHODE CORRIGÉE - Logique de détermination de direction avec deadzone plus stricte
  String _getDirection(double x, double y, double seuil) {
    // Zone morte d'abord - PLUS STRICTE
    double amplitude = sqrt(x * x + y * y);
    if (amplitude < seuil) {
      return "stop";
    }
    
    double absX = x.abs();
    double absY = y.abs();
    
    // CORRECTION: Seuils plus précis pour éviter les rotations accidentelles
    const double cardinalThreshold = 0.15; // Plus strict pour les mouvements purs
    
    // Si mouvement principalement horizontal (et pas trop diagonal)
    if (absX > absY + cardinalThreshold && absX > seuil) {
      if (x > 0) {
        return "right";
      } else {
        return "left";
      }
    }
    
    // Si mouvement principalement vertical (et pas trop diagonal)
    if (absY > absX + cardinalThreshold && absY > seuil) {
      if (y < 0) {
        return "forward";
      } else {
        return "backward";
      }
    }
    
    // Diagonales - SEUIL PLUS ÉLEVÉ pour éviter les accidents
    if (absX > seuil * 0.8 && absY > seuil * 0.8) {
      if (y < 0 && x > 0) {
        return "forward_right";
      }
      if (y < 0 && x < 0) {
        return "forward_left";
      }
      if (y > 0 && x > 0) {
        return "backward_right";
      }
      if (y > 0 && x < 0) {
        return "backward_left";
      }
    }
    
    // Si aucune direction claire, STOP par sécurité
    return "stop";
  }
  
  // MÉTHODE CORRIGÉE - Traiter le mouvement du joystick avec protection renforcée
  void handleJoystickMove(double x, double y) {
    print('Joystick RAW: x=${x.toStringAsFixed(2)}, y=${y.toStringAsFixed(2)}');

    // SEUIL PLUS STRICT pour éviter les mouvements accidentels
    const seuil = 0.5; // Augmenté de 0.4 à 0.5
    
    String currentDirection = _getDirection(x, y, seuil);
    
    // PROTECTION ANTI-BOUCLE renforcée
    if (currentDirection == _lastSentCommand) {
      // Même commande = on reset le timer de sécurité si c'est un mouvement
      if (currentDirection != "stop") {
        _resetForceStopTimer();
      }
      return;
    }
    
    // PROTECTION: Éviter les changements trop rapides
    if (_lastCommandTime != null) {
      final timeSinceLastCommand = DateTime.now().difference(_lastCommandTime!);
      if (timeSinceLastCommand.inMilliseconds < 100) {
        print('⚠️ Commande trop rapide, ignorée: $currentDirection');
        return;
      }
    }
    
    print("🎮 Changement: $_lastSentCommand -> $currentDirection");
    
    // Annuler le timer de force stop si on envoie un stop manuel
    if (currentDirection == "stop") {
      _forceStopTimer?.cancel();
    }
    
    _lastSentCommand = currentDirection;
    _isMoving = (currentDirection != "stop");
    _lastCommandController.add(currentDirection);
    
    // Envoyer la commande
    sendCommand(currentDirection);
  }
  
  // NOUVELLE MÉTHODE: Arrêt manuel forcé (pour l'UI)
  void forceStop() {
    print('🛑 ARRÊT FORCÉ MANUEL');
    _forceStopTimer?.cancel();
    _lastSentCommand = "stop";
    _isMoving = false;
    _lastCommandController.add("stop");
    sendCommand("stop");
  }
  
  // Nettoyer les ressources
  void dispose() {
    _commandTimer?.cancel();
    _forceStopTimer?.cancel();
    _commandController.close();
    _lastCommandController.close();
  }
}